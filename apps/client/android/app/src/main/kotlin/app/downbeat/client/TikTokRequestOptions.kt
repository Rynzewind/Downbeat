package app.downbeat.client

import java.net.URI

object TikTokRequestOptions {
    fun forUrl(url: String): List<Pair<String, String>> {
        val host = runCatching { URI(url).host.orEmpty().lowercase() }.getOrDefault("")
        if (host != "tiktok.com" && !host.endsWith(".tiktok.com")) return emptyList()
        return listOf("--user-agent" to "Downbeat/1.0")
    }
}
