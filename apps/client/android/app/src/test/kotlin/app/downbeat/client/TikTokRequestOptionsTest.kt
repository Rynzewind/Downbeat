package app.downbeat.client

import org.junit.Assert.assertEquals
import org.junit.Test

class TikTokRequestOptionsTest {
    @Test
    fun `uses neutral app user agent for TikTok challenge fallback`() {
        assertEquals(
            listOf("--user-agent" to "Downbeat/1.0"),
            TikTokRequestOptions.forUrl("https://www.tiktok.com/@downbeat/video/7694128065860979990"),
        )
    }

    @Test
    fun `does not alter requests to other sites`() {
        assertEquals(emptyList<Pair<String, String>>(), TikTokRequestOptions.forUrl("https://example.com/video"))
    }
}
