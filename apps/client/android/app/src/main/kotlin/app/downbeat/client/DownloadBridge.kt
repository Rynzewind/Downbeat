package app.downbeat.client

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.ReturnCode
import com.chaquo.python.Python
import dev.ffmpegkit_maintained.ytdlp.YtDlp
import dev.ffmpegkit_maintained.ytdlp.YtDlpRequest
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicReference

class DownloadBridge(private val context: Context) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var active: Future<*>? = null
    private var activeJobId: String? = null

    init {
        instance = this
        YtDlp.init(context.applicationContext)
        installCurrentYtDlp(context.applicationContext)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(call, result)
            "cancel" -> { cancel(call.argument<String>("jobId")); result.success(null) }
            "recover" -> result.success(activeJobId)
            else -> result.notImplemented()
        }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        if (active != null) { result.error("busy", "A download is already running", null); return }
        val jobId = call.argument<String>("jobId") ?: return result.error("request", "Missing job id", null)
        val url = call.argument<String>("url") ?: return result.error("request", "Missing URL", null)
        val format = call.argument<String>("format") ?: "mp4"
        val workspace = File(call.argument<String>("workspacePath")!!).apply { mkdirs() }
        val cookies = call.argument<String>("cookieFilePath")
        val output = File(workspace, if (format == "mp3") "%(title).180B [%(id)s].source.%(ext)s" else "%(title).180B [%(id)s].video.%(ext)s")
        val request = YtDlpRequest(url).setOutputTemplate(output.absolutePath)
            .addOption("--no-playlist")
            .addOption("--no-part")
            .addOption("--format", if (format == "mp3") "bestaudio/best" else "bestvideo[ext=mp4][height<=720]/bestvideo[height<=720]")
        configureSiteOptions(request, url)
        if (cookies != null) request.addOption("--cookies", cookies)
        activeJobId = jobId
        ContextCompat.startForegroundService(context, Intent(context, DownbeatDownloadService::class.java))
        emit(mapOf("jobId" to jobId, "type" to "stage", "stage" to "fetching", "message" to "Finding media"))
        val diagnostic = AtomicReference("")
        active = YtDlp.executeDebug(request, { level, message ->
            if (level.equals("error", ignoreCase = true) || message.contains("ERROR:", ignoreCase = true)) {
                diagnostic.set(message.takeLast(1000))
            }
        }) { progress, _, _ ->
            val overall = if (format == "mp4") (progress * 0.75).toInt() else progress.toInt()
            emit(mapOf("jobId" to jobId, "type" to "progress", "stage" to "downloading", "percent" to overall, "bytesReceived" to 0))
            notify("Downloading $overall%", overall)
        }
        Thread {
            try {
                active!!.get()
                var artifact = workspace.walkTopDown().filter { it.isFile && it.name != "cookies.txt" }.maxByOrNull { it.lastModified() }
                    ?: throw IllegalStateException("No downloaded file was produced")
                if (format == "mp3") {
                    emit(mapOf("jobId" to jobId, "type" to "stage", "stage" to "converting", "message" to "Converting audio"))
                    val converted = File(workspace, artifact.name.substringBeforeLast('.') + ".mp3")
                    val command = "-y -i ${quote(artifact.absolutePath)} -vn -codec:a libmp3lame ${quote(converted.absolutePath)}"
                    val session = FFmpegKit.execute(command)
                    if (!ReturnCode.isSuccess(session.returnCode)) throw IllegalStateException("Audio conversion failed")
                    artifact.delete()
                    artifact = converted
                } else {
                    val video = artifact
                    val audioRequest = YtDlpRequest(url)
                        .setOutputTemplate(File(workspace, "downbeat-audio.%(ext)s").absolutePath)
                        .addOption("--no-playlist")
                        .addOption("--no-part")
                        .addOption("--format", "bestaudio[ext=m4a]/bestaudio")
                    configureSiteOptions(audioRequest, url)
                    if (cookies != null) audioRequest.addOption("--cookies", cookies)
                    active = YtDlp.executeDebug(audioRequest, { level, message ->
                        if (level.equals("error", ignoreCase = true) || message.contains("ERROR:", ignoreCase = true)) {
                            diagnostic.set(message.takeLast(1000))
                        }
                    }) { progress, _, _ ->
                        val overall = 75 + (progress * 0.2).toInt()
                        emit(mapOf("jobId" to jobId, "type" to "progress", "stage" to "downloading", "percent" to overall, "bytesReceived" to 0))
                        notify("Downloading audio $overall%", overall)
                    }
                    active!!.get()
                    val audio = workspace.walkTopDown().filter { it.isFile && it.name.startsWith("downbeat-audio.") }.firstOrNull()
                        ?: throw IllegalStateException("No audio stream was produced")
                    emit(mapOf("jobId" to jobId, "type" to "stage", "stage" to "converting", "message" to "Merging video and audio"))
                    val baseName = video.name.replace(Regex("\\.video\\.[^.]+$"), "")
                    val merged = File(workspace, "$baseName.mp4")
                    val command = "-y -i ${quote(video.absolutePath)} -i ${quote(audio.absolutePath)} -c:v copy -c:a aac -movflags +faststart ${quote(merged.absolutePath)}"
                    val session = FFmpegKit.execute(command)
                    if (!ReturnCode.isSuccess(session.returnCode)) throw IllegalStateException("Video merge failed")
                    video.delete()
                    audio.delete()
                    artifact = merged
                }
                emit(mapOf("jobId" to jobId, "type" to "artifact", "path" to artifact.absolutePath, "filename" to artifact.name, "mediaType" to if (format == "mp3") "audio/mpeg" else "video/mp4", "size" to artifact.length()))
                notify("Download completed", 100)
            } catch (error: Exception) {
                val details = listOfNotNull(error.message, error.cause?.message, diagnostic.get()).joinToString(" ")
                val failure = safeFailure(details)
                emit(mapOf("jobId" to jobId, "type" to "failure", "category" to failure.first, "message" to failure.second))
            } finally {
                active = null; activeJobId = null
                context.stopService(Intent(context, DownbeatDownloadService::class.java))
            }
        }.start()
        result.success(null)
    }

    private fun cancel(jobId: String?) { if (jobId == activeJobId) active?.cancel(true) }
    private fun emit(value: Map<String, Any?>) = main.post { sink?.success(value) }
    private fun notify(text: String, progress: Int?) {
        val manager = context.getSystemService(android.app.NotificationManager::class.java)
        main.post { manager.notify(DownloadNotification.NOTIFICATION_ID, DownloadNotification.build(context, text, progress)) }
    }
    private fun quote(value: String) = "\"${value.replace("\"", "\\\"")}\""

    private fun configureSiteOptions(request: YtDlpRequest, url: String) {
        val host = runCatching { android.net.Uri.parse(url).host.orEmpty().lowercase() }.getOrDefault("")
        if (host == "youtube.com" || host.endsWith(".youtube.com") || host == "youtu.be") {
            request.addOption("--extractor-args", "youtube:player_client=visionos")
            request.addOption("--remote-components", "ejs:github")
        }
    }

    private fun safeFailure(details: String): Pair<String, String> {
        val value = details.lowercase()
        return when {
            "drm" in value -> "protected_media" to "This protected media cannot be downloaded."
            "sign in" in value || "not a bot" in value || "cookies" in value ->
                "authentication" to "This site needs a signed-in browser session. Sign in inside Downbeat, then try again."
            "private video" in value -> "authentication" to "This video is private or your Downbeat browser is not signed in to the account that can view it."
            "video unavailable" in value || "not available" in value ->
                "unavailable" to "This video is unavailable to this device or account."
            "geo" in value || "country" in value ->
                "unavailable" to "This video is not available in your current region."
            "requested format" in value ->
                "format" to "That video does not offer a compatible stream. Try the other format."
            "javascript" in value || "js runtime" in value || "signature" in value ->
                "extractor" to "YouTube changed its player. This Downbeat build needs an extractor update."
            else -> "download" to "Downbeat could not download this page. The site rejected the media request."
        }
    }

    private fun installCurrentYtDlp(appContext: Context) {
        val assetName = "python/yt_dlp-2026.10.10.233141.dev0-py3-none-any.whl"
        val wheel = File(appContext.filesDir, assetName.substringAfterLast('/'))
        if (!wheel.exists() || wheel.length() == 0L) {
            appContext.assets.open(assetName).use { input ->
                wheel.outputStream().use { output -> input.copyTo(output) }
            }
        }
        val python = Python.getInstance()
        python.getModule("sys").get("path")?.callAttr("insert", 0, wheel.absolutePath)
        python.getModule("importlib").callAttr("invalidate_caches")
    }

    companion object {
        private var instance: DownloadBridge? = null
        fun cancelActive() { instance?.cancel(instance?.activeJobId) }
    }
}
