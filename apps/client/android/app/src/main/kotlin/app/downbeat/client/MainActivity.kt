package app.downbeat.client

import android.content.Intent
import android.content.ContentValues
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebView
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var sharedText: String? = null
    private var shareSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sharedText = extractSharedText(intent)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.downbeat/share"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getInitialSharedText") {
                result.success(sharedText.also { sharedText = null })
            } else {
                result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "app.downbeat/share-events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { shareSink = events }
            override fun onCancel(arguments: Any?) { shareSink = null }
        })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.downbeat/browser").setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookies" -> result.success(CookieManager.getInstance().getCookie(call.arguments as String))
                "enableAutofill" -> {
                    enableBrowserAutofill(window.decorView)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.downbeat/delivery").setMethodCallHandler { call, result ->
            when (call.method) {
                "publish" -> publishDownload(call.argument<String>("path")!!, call.argument<String>("filename")!!, call.argument<String>("mediaType")!!, result)
                "open" -> openDownload(call.arguments as String, result)
                else -> result.notImplemented()
            }
        }
        val bridge = DownloadBridge(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.downbeat/processor").setMethodCallHandler(bridge)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "app.downbeat/processor-events").setStreamHandler(bridge)
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 4102)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractSharedText(intent)?.let { shareSink?.success(it) ?: run { sharedText = it } }
    }

    private fun publishDownload(path: String, filename: String, mediaType: String, result: MethodChannel.Result) {
        try {
            val collection = if (mediaType.startsWith("audio/")) MediaStore.Audio.Media.EXTERNAL_CONTENT_URI else MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                put(MediaStore.MediaColumns.MIME_TYPE, mediaType)
                if (Build.VERSION.SDK_INT >= 29) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }
            val uri = contentResolver.insert(collection, values) ?: error("Could not create Downloads entry")
            contentResolver.openOutputStream(uri)?.use { output -> File(path).inputStream().use { it.copyTo(output) } }
                ?: error("Could not write Downloads entry")
            if (Build.VERSION.SDK_INT >= 29) {
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            }
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error(
                "publish",
                "Could not save the completed download",
                "${error.javaClass.simpleName}: ${error.message.orEmpty()}"
            )
        }
    }

    private fun openDownload(value: String, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(value)
            val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri, contentResolver.getType(uri)).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) { result.error("open", "No app can open this download", null) }
    }

    private fun extractSharedText(intent: Intent?): String? =
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            intent.getStringExtra(Intent.EXTRA_TEXT)
        } else {
            null
        }

    private fun enableBrowserAutofill(view: View) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (view is WebView) {
            view.importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_YES
            return
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) enableBrowserAutofill(view.getChildAt(index))
        }
    }
}
