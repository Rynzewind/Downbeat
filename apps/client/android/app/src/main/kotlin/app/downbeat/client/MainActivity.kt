package app.downbeat.client

import android.app.Activity
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
import androidx.documentfile.provider.DocumentFile
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var sharedText: String? = null
    private var shareSink: EventChannel.EventSink? = null
    private var folderPickerResult: MethodChannel.Result? = null

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
                "getDownloadLocation" -> result.success(downloadLocation())
                "chooseDownloadLocation" -> {
                    if (folderPickerResult != null) result.error("busy", "The folder picker is already open", null)
                    else {
                        folderPickerResult = result
                        startActivityForResult(
                            Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                            ),
                            FOLDER_PICKER_REQUEST
                        )
                    }
                }
                "resetDownloadLocation" -> {
                    getSharedPreferences("downbeat", MODE_PRIVATE).edit().remove("downloadTree").apply()
                    result.success(downloadLocation())
                }
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

    @Deprecated("Required by FlutterActivity's compatible folder picker API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != FOLDER_PICKER_REQUEST) return
        val pending = folderPickerResult.also { folderPickerResult = null } ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.success(null)
            return
        }
        try {
            val flags = data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            contentResolver.takePersistableUriPermission(uri, flags)
            getSharedPreferences("downbeat", MODE_PRIVATE).edit()
                .putString("downloadTree", uri.toString()).apply()
            pending.success(downloadLocation())
        } catch (error: Exception) {
            pending.error(
                "folder",
                "Downbeat cannot write to that folder",
                "${error.javaClass.simpleName}: ${error.message.orEmpty()}"
            )
        }
    }

    private fun publishDownload(path: String, filename: String, mediaType: String, result: MethodChannel.Result) {
        val customTree = getSharedPreferences("downbeat", MODE_PRIVATE).getString("downloadTree", null)
        if (customTree != null) {
            publishToChosenFolder(Uri.parse(customTree), path, filename, mediaType, result)
            return
        }
        var pendingUri: Uri? = null
        try {
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else if (mediaType.startsWith("audio/")) {
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            } else {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                put(MediaStore.MediaColumns.MIME_TYPE, mediaType)
                if (Build.VERSION.SDK_INT >= 29) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }
            val uri = contentResolver.insert(collection, values) ?: error("Could not create Downloads entry")
            pendingUri = uri
            contentResolver.openOutputStream(uri)?.use { output -> File(path).inputStream().use { it.copyTo(output) } }
                ?: error("Could not write Downloads entry")
            if (Build.VERSION.SDK_INT >= 29) {
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            }
            pendingUri = null
            result.success(uri.toString())
        } catch (error: Exception) {
            pendingUri?.let { runCatching { contentResolver.delete(it, null, null) } }
            result.error(
                "publish",
                "Could not save the completed download",
                "${error.javaClass.simpleName}: ${error.message.orEmpty()}"
            )
        }
    }

    private fun publishToChosenFolder(treeUri: Uri, path: String, filename: String, mediaType: String, result: MethodChannel.Result) {
        var document: DocumentFile? = null
        try {
            val directory = DocumentFile.fromTreeUri(this, treeUri)
                ?.takeIf { it.exists() && it.isDirectory && it.canWrite() }
                ?: error("The selected folder is no longer writable")
            document = directory.createFile(mediaType, filename)
                ?: error("Could not create the download in the selected folder")
            contentResolver.openOutputStream(document.uri)?.use { output ->
                File(path).inputStream().use { input -> input.copyTo(output) }
            } ?: error("Could not write the download to the selected folder")
            result.success(document.uri.toString())
        } catch (error: Exception) {
            document?.delete()
            result.error(
                "publish",
                "Could not save the completed download",
                "${error.javaClass.simpleName}: ${error.message.orEmpty()}"
            )
        }
    }

    private fun downloadLocation(): Map<String, String> {
        val saved = getSharedPreferences("downbeat", MODE_PRIVATE).getString("downloadTree", null)
            ?: return mapOf("label" to "Downloads", "mode" to "default")
        val uri = Uri.parse(saved)
        val directory = DocumentFile.fromTreeUri(this, uri)
        if (directory == null || !directory.exists() || !directory.isDirectory || !directory.canWrite()) {
            getSharedPreferences("downbeat", MODE_PRIVATE).edit().remove("downloadTree").apply()
            return mapOf("label" to "Downloads", "mode" to "default")
        }
        return mapOf("label" to (directory.name ?: "Selected folder"), "mode" to "custom")
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

    companion object {
        private const val FOLDER_PICKER_REQUEST = 4103
    }
}
