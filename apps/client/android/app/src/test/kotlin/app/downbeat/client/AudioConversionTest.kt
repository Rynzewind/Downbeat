package app.downbeat.client

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AudioConversionTest {
    @Test
    fun `publishes an existing mp3 without converting it in place`() {
        val source = File("download.source.mp3")

        val plan = AudioConversion.plan(source)

        assertFalse(plan.requiresConversion)
        assertEquals(source, plan.output)
    }

    @Test
    fun `converts other audio containers to a distinct mp3 file`() {
        val source = File("download.source.m4a")

        val plan = AudioConversion.plan(source)

        assertTrue(plan.requiresConversion)
        assertEquals(File("download.source.mp3"), plan.output)
    }
}
