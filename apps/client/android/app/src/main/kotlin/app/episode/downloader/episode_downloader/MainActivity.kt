package app.episode.downloader.episode_downloader

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var sharedText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sharedText = extractSharedText(intent)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "episode_downloader/share"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getInitialSharedText") {
                result.success(sharedText.also { sharedText = null })
            } else {
                result.notImplemented()
            }
        }
    }

    private fun extractSharedText(intent: Intent?): String? =
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            intent.getStringExtra(Intent.EXTRA_TEXT)
        } else {
            null
        }
}
