package app.downbeat.client

import org.junit.Assert.assertEquals
import org.junit.Test

class PythonRuntimePackagesTest {
    @Test
    fun `loads yt-dlp and its matching EJS solver package`() {
        assertEquals(
            listOf(
                "python/yt_dlp-2026.10.10.233141.dev0-py3-none-any.whl",
                "python/yt_dlp_ejs-0.8.0-py3-none-any.whl",
            ),
            PythonRuntimePackages.assets,
        )
    }
}
