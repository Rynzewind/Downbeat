package app.downbeat.client

import java.net.URI

object YouTubeRuntimeOptions {
    fun forUrl(url: String, quickJsPath: String): List<Pair<String, String>> {
        val host = runCatching { URI(url).host.orEmpty().lowercase() }.getOrDefault("")
        if (host != "youtube.com" && !host.endsWith(".youtube.com") && host != "youtu.be") {
            return emptyList()
        }
        return listOf(
            "--js-runtimes" to "quickjs:$quickJsPath",
            "--remote-components" to "ejs:github",
        )
    }
}
