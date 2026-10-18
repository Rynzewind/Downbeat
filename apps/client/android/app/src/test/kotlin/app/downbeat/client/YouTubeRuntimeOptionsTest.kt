package app.downbeat.client

import org.junit.Assert.assertEquals
import org.junit.Test

class YouTubeRuntimeOptionsTest {
    @Test
    fun `uses bundled QuickJS for YouTube requests`() {
        assertEquals(
            listOf(
                "--js-runtimes" to "quickjs:/native/libqjs.so",
                "--remote-components" to "ejs:github",
            ),
            YouTubeRuntimeOptions.forUrl(
                "https://www.youtube.com/watch?v=FdZMDDejWVA",
                "/native/libqjs.so",
            ),
        )
    }

    @Test
    fun `does not add YouTube runtime options to other sites`() {
        assertEquals(
            emptyList<Pair<String, String>>(),
            YouTubeRuntimeOptions.forUrl(
                "https://www.bbc.co.uk/iplayer/episode/example",
                "/native/libqjs.so",
            ),
        )
    }
}
