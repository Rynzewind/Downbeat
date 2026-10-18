package app.downbeat.client

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ConversionProgressTest {
    @Test
    fun `maps processed media time into the reserved progress range`() {
        assertEquals(
            ConversionProgress(overallPercent = 90, phasePercent = 50, etaSeconds = 15),
            ConversionProgress.calculate(
                processedMilliseconds = 30_000,
                durationMilliseconds = 60_000,
                processingSpeed = 2.0,
                startPercent = 80,
                endPercent = 99,
            ),
        )
    }

    @Test
    fun `keeps conversion below completion until the artifact is published`() {
        assertEquals(
            ConversionProgress(overallPercent = 99, phasePercent = 100, etaSeconds = 0),
            ConversionProgress.calculate(
                processedMilliseconds = 75_000,
                durationMilliseconds = 60_000,
                processingSpeed = 1.0,
                startPercent = 95,
                endPercent = 99,
            ),
        )
    }

    @Test
    fun `uses indeterminate progress when duration is unavailable`() {
        val progress = ConversionProgress.calculate(
            processedMilliseconds = 10_000,
            durationMilliseconds = null,
            processingSpeed = 1.0,
            startPercent = 80,
            endPercent = 99,
        )

        assertNull(progress.overallPercent)
        assertNull(progress.phasePercent)
        assertNull(progress.etaSeconds)
    }

    @Test
    fun `formats a concise phase percentage and eta`() {
        assertEquals(
            "Converting audio · 50% · about 15s left",
            ConversionProgress(overallPercent = 90, phasePercent = 50, etaSeconds = 15)
                .message("Converting audio"),
        )
    }
}
