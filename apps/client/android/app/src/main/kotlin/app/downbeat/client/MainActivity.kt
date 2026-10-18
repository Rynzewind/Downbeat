package app.downbeat.client

import android.content.Intent
import android.webkit.CookieManager
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
            if (call.method == "getCookies") result.success(CookieManager.getInstance().getCookie(call.arguments as String)) else result.notImplemented()
        }
        val bridge = DownloadBridge(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.downbeat/processor").setMethodCallHandler(bridge)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "app.downbeat/processor-events").setStreamHandler(bridge)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractSharedText(intent)?.let { shareSink?.success(it) ?: run { sharedText = it } }
    }

    private fun extractSharedText(intent: Intent?): String? =
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            intent.getStringExtra(Intent.EXTRA_TEXT)
        } else {
            null
        }
}
