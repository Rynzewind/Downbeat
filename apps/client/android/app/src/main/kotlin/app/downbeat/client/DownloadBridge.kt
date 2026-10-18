package app.downbeat.client

import android.content.Context
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
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
import java.nio.ByteBuffer
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

class DownloadBridge(private val context: Context) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var active: Future<*>? = null
    private var activeJobId: String? = null
    private var pythonRuntimeStatus = "Python runtime not checked"

    init {
        instance = this
        YtDlp.init(context.applicationContext)
        pythonRuntimeStatus = installCurrentYtDlp(context.applicationContext)
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
            .addOption(
                "--format",
                if (format == "mp3") {
                    "bestaudio/best"
                } else {
                    "bestvideo[ext=mp4][vcodec^=avc1][height<=720]/bestvideo[ext=mp4][height<=720]/bestvideo[height<=720]/best[ext=mp4][height<=720]/best[height<=720]/best"
                }
            )
        configureSiteOptions(request, url)
        if (cookies != null) request.addOption("--cookies", cookies)
        activeJobId = jobId
        ContextCompat.startForegroundService(context, Intent(context, DownbeatDownloadService::class.java))
        emit(mapOf("jobId" to jobId, "type" to "stage", "stage" to "fetching", "message" to "Finding media"))
        val diagnostic = AtomicReference(runtimeStatus(url))
        active = YtDlp.executeDebug(request, { level, message ->
            if (level.equals("error", ignoreCase = true) ||
                level.equals("warning", ignoreCase = true) ||
                message.contains("ERROR:", ignoreCase = true) ||
                message.contains("WARNING:", ignoreCase = true) ||
                message.contains("[jsc", ignoreCase = true) ||
                message.contains("JS runtimes", ignoreCase = true) ||
                message.contains("EJS", ignoreCase = true)
            ) {
                diagnostic.updateAndGet { "$it\n$message".takeLast(8000) }
            }
        }) { progress, _, line ->
            val overall = if (format == "mp4") (progress * 0.75).toInt() else progress.toInt()
            emitProgress(jobId, overall, line)
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
                    if (!ReturnCode.isSuccess(session.returnCode)) {
                        throw IllegalStateException("Audio conversion failed (${session.returnCode}): ${session.allLogsAsString.takeLast(1200)}")
                    }
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
                        if (level.equals("error", ignoreCase = true) ||
                            level.equals("warning", ignoreCase = true) ||
                            message.contains("ERROR:", ignoreCase = true) ||
                            message.contains("WARNING:", ignoreCase = true) ||
                            message.contains("[jsc", ignoreCase = true) ||
                            message.contains("JS runtimes", ignoreCase = true) ||
                            message.contains("EJS", ignoreCase = true)
                        ) {
                            diagnostic.updateAndGet { "$it\n$message".takeLast(8000) }
                        }
                    }) { progress, _, line ->
                        val overall = 75 + (progress * 0.2).toInt()
                        emitProgress(jobId, overall, line)
                        notify("Downloading audio $overall%", overall)
                    }
                    active!!.get()
                    val audio = workspace.walkTopDown().filter { it.isFile && it.name.startsWith("downbeat-audio.") }.firstOrNull()
                        ?: throw IllegalStateException("No audio stream was produced")
                    emit(mapOf("jobId" to jobId, "type" to "stage", "stage" to "converting", "message" to "Finalising video"))
                    val baseName = video.name.replace(Regex("\\.video\\.[^.]+$"), "")
                    val merged = File(workspace, "$baseName.mp4")
                    mergeMp4(video, audio, merged)
                    video.delete()
                    audio.delete()
                    artifact = merged
                }
                emit(mapOf("jobId" to jobId, "type" to "artifact", "path" to artifact.absolutePath, "filename" to artifact.name, "mediaType" to if (format == "mp3") "audio/mpeg" else "video/mp4", "size" to artifact.length()))
                notify("Download completed", 100)
            } catch (error: Throwable) {
                val details = listOfNotNull(error.message, error.cause?.message, diagnostic.get()).joinToString(" ")
                val failure = safeFailure(details)
                val debug = sanitizeDiagnostic("${error.javaClass.simpleName}: $details", workspace)
                emit(mapOf("jobId" to jobId, "type" to "failure", "category" to failure.first, "message" to "${failure.second}\nDebug: $debug"))
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
            request.addOption("--verbose")
            request.addOption(
                "--extractor-args",
                "youtube:player_client=web_safari,web_embedded,-tv_downgraded;formats=missing_pot"
            )
            val quickJs = File(context.applicationInfo.nativeLibraryDir, "libqjs.so")
            if (!quickJs.isFile) {
                throw IllegalStateException("Bundled QuickJS runtime is missing")
            }
            YouTubeRuntimeOptions.forUrl(url, quickJs.absolutePath).forEach { (option, value) ->
                request.addOption(option, value)
            }
        }
    }

    private fun runtimeStatus(url: String): String {
        if (YouTubeRuntimeOptions.forUrl(url, "unused").isEmpty()) return pythonRuntimeStatus
        val quickJs = File(context.applicationInfo.nativeLibraryDir, "libqjs.so")
        val quickJsResult = runCatching {
            val process = ProcessBuilder(quickJs.absolutePath, "-e", "console.log('downbeat-qjs-ok')")
                .redirectErrorStream(true)
                .start()
            val finished = process.waitFor(5, TimeUnit.SECONDS)
            if (!finished) {
                process.destroyForcibly()
                "timeout"
            } else {
                "exit=${process.exitValue()}, output=${process.inputStream.bufferedReader().readText().trim()}"
            }
        }.getOrElse { "failed=${it.javaClass.simpleName}:${it.message}" }
        return "$pythonRuntimeStatus; QuickJS exists=${quickJs.isFile}, executable=${quickJs.canExecute()}, test=$quickJsResult"
    }

    private fun emitProgress(jobId: String, percent: Int, line: String) {
        val details = parseProgress(line, percent)
        emit(
            mapOf(
                "jobId" to jobId,
                "type" to "progress",
                "stage" to "downloading",
                "percent" to percent,
                "bytesReceived" to details.received,
                "totalBytes" to details.total,
                "message" to details.speed,
            )
        )
    }

    private fun parseProgress(line: String, percent: Int): DownloadDetails {
        val totalMatch = Regex(
            "(?i)of\\s+~?\\s*([0-9]+(?:\\.[0-9]+)?)\\s*([KMGT]?i?B)"
        ).find(line)
        val speedMatch = Regex(
            "(?i)at\\s+([0-9]+(?:\\.[0-9]+)?)\\s*([KMGT]?i?B)/s"
        ).find(line)
        val total = totalMatch?.let {
            byteCount(it.groupValues[1].toDoubleOrNull(), it.groupValues[2])
        }
        val received = total?.let { (it * percent.coerceIn(0, 100) / 100.0).toLong() } ?: 0L
        val speed = speedMatch?.let { "Speed: ${it.groupValues[1]} ${it.groupValues[2]}/s" }
        return DownloadDetails(received, total, speed)
    }

    private fun byteCount(value: Double?, unit: String): Long? {
        if (value == null) return null
        val multiplier = when (unit.uppercase()) {
            "KIB", "KB" -> 1L shl 10
            "MIB", "MB" -> 1L shl 20
            "GIB", "GB" -> 1L shl 30
            "TIB", "TB" -> 1L shl 40
            else -> 1L
        }
        return (value * multiplier).toLong()
    }

    private fun safeFailure(details: String): Pair<String, String> {
        val value = details.lowercase()
        return when {
            "drm" in value -> "protected_media" to "This protected media cannot be downloaded."
            "sign in" in value || "not a bot" in value || "cookies" in value ->
                "authentication" to "This site needs a signed-in browser session. Sign in inside Downbeat, then try again."
            "private video" in value -> "authentication" to "This video is private or your Downbeat browser is not signed in to the account that can view it."
            "javascript" in value || "js runtime" in value || "signature" in value ->
                "extractor" to "YouTube's player challenge could not be solved. Copy the debug details so Downbeat can identify the failed component."
            "requested format" in value ->
                "format" to "That video does not offer a compatible stream. Try the other format."
            "video unavailable" in value || "not available" in value ->
                "unavailable" to "This video is unavailable to this device or account."
            "geo" in value || "country" in value ->
                "unavailable" to "This video is not available in your current region."
            "unsatisfiedlink" in value || "native" in value && "load" in value ->
                "conversion" to "This phone could not start the audio converter."
            else -> "download" to "Downbeat could not download this page. The site rejected the media request."
        }
    }

    private fun sanitizeDiagnostic(value: String, workspace: File): String = value
        .replace(workspace.absolutePath, "[workspace]", ignoreCase = true)
        .replace(Regex("https?://\\S+", RegexOption.IGNORE_CASE), "[url]")
        .replace(Regex("(?i)(cookie|authorization|token)[=:]\\s*\\S+"), "\$1=[hidden]")
        .replace(Regex("\\s+"), " ")
        .take(3000)

    private fun mergeMp4(video: File, audio: File, output: File) {
        output.delete()
        val copyCommand = "-y -i ${quote(video.absolutePath)} -i ${quote(audio.absolutePath)} " +
            "-map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -b:a 192k -movflags +faststart ${quote(output.absolutePath)}"
        val copySession = FFmpegKit.execute(copyCommand)
        if (ReturnCode.isSuccess(copySession.returnCode) && output.exists() && output.length() > 0L) return

        output.delete()
        val compatibleCommand = "-y -i ${quote(video.absolutePath)} -i ${quote(audio.absolutePath)} " +
            "-map 0:v:0 -map 1:a:0 -c:v mpeg4 -q:v 4 -c:a aac -b:a 192k -movflags +faststart ${quote(output.absolutePath)}"
        val compatibleSession = FFmpegKit.execute(compatibleCommand)
        if (ReturnCode.isSuccess(compatibleSession.returnCode) && output.exists() && output.length() > 0L) return
        throw IllegalStateException(
            "Video conversion failed (${compatibleSession.returnCode}): " +
                compatibleSession.allLogsAsString.takeLast(1200)
        )
    }

    @Suppress("unused")
    private fun mergeMp4WithPlatformMuxer(video: File, audio: File, output: File) {
        val videoExtractor = MediaExtractor()
        val audioExtractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        var started = false
        try {
            videoExtractor.setDataSource(video.absolutePath)
            audioExtractor.setDataSource(audio.absolutePath)
            val videoSourceTrack = findTrack(videoExtractor, "video/")
            val audioSourceTrack = findTrack(audioExtractor, "audio/")
            val videoFormat = videoExtractor.getTrackFormat(videoSourceTrack)
            val audioFormat = audioExtractor.getTrackFormat(audioSourceTrack)
            output.delete()
            muxer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val videoDestinationTrack = muxer.addTrack(videoFormat)
            val audioDestinationTrack = muxer.addTrack(audioFormat)
            muxer.start()
            started = true
            copyTrack(videoExtractor, videoSourceTrack, muxer, videoDestinationTrack, bufferSize(videoFormat))
            copyTrack(audioExtractor, audioSourceTrack, muxer, audioDestinationTrack, bufferSize(audioFormat))
        } finally {
            if (started) runCatching { muxer?.stop() }
            runCatching { muxer?.release() }
            videoExtractor.release()
            audioExtractor.release()
        }
        if (!output.exists() || output.length() == 0L) throw IllegalStateException("Video merge failed")
    }

    private data class DownloadDetails(
        val received: Long,
        val total: Long?,
        val speed: String?,
    )

    private fun findTrack(extractor: MediaExtractor, prefix: String): Int {
        for (index in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME).orEmpty()
            if (mime.startsWith(prefix)) return index
        }
        throw IllegalStateException("Downloaded media is missing its ${prefix.removeSuffix("/")} track")
    }

    private fun bufferSize(format: MediaFormat): Int {
        val declared = if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
            format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
        } else {
            0
        }
        return declared.coerceIn(1 shl 20, 16 shl 20)
    }

    private fun copyTrack(
        extractor: MediaExtractor,
        sourceTrack: Int,
        muxer: MediaMuxer,
        destinationTrack: Int,
        bufferSize: Int,
    ) {
        extractor.selectTrack(sourceTrack)
        val buffer = ByteBuffer.allocateDirect(bufferSize)
        val info = MediaCodec.BufferInfo()
        while (true) {
            buffer.clear()
            val size = extractor.readSampleData(buffer, 0)
            if (size < 0) break
            info.set(0, size, extractor.sampleTime, extractor.sampleFlags)
            muxer.writeSampleData(destinationTrack, buffer, info)
            extractor.advance()
        }
        extractor.unselectTrack(sourceTrack)
    }

    private fun installCurrentYtDlp(appContext: Context): String {
        val wheels = PythonRuntimePackages.assets.map { assetName ->
            val wheel = File(appContext.filesDir, assetName.substringAfterLast('/'))
            if (!wheel.exists() || wheel.length() == 0L) {
                appContext.assets.open(assetName).use { input ->
                    wheel.outputStream().use { output -> input.copyTo(output) }
                }
            }
            wheel
        }
        val python = Python.getInstance()
        val path = python.getModule("sys").get("path")
        wheels.asReversed().forEach { wheel -> path?.callAttr("insert", 0, wheel.absolutePath) }
        python.getModule("importlib").callAttr("invalidate_caches")
        return runCatching {
            val ejsVersion = python.getModule("yt_dlp_ejs").get("version")?.toString().orEmpty()
            val dependency = python.getModule("yt_dlp.dependencies").get("yt_dlp_ejs")
            "EJS version=$ejsVersion, registered=${dependency != null && dependency.toString() != "None"}"
        }.getOrElse { "EJS import failed=${it.javaClass.simpleName}:${it.message}" }
    }

    companion object {
        private var instance: DownloadBridge? = null
        fun cancelActive() { instance?.cancel(instance?.activeJobId) }
    }
}
