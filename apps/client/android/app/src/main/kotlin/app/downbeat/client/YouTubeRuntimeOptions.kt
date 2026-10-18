package app.downbeat.client

import java.net.URI

object YouTubeRuntimeOptions {
    private fun isYouTube(url: String): Boolean {
        val host = runCatching { URI(url).host.orEmpty().lowercase() }.getOrDefault("")
        return host == "youtube.com" || host.endsWith(".youtube.com") || host == "youtu.be"
    }

    fun shouldAttachCookies(url: String): Boolean = !isYouTube(url)

    fun forUrl(url: String, quickJsPath: String): List<Pair<String, String>> {
        if (!isYouTube(url)) {
            return emptyList()
        }
        return listOf(
            "--js-runtimes" to "quickjs:$quickJsPath",
            "--remote-components" to "ejs:github",
        )
    }
}
