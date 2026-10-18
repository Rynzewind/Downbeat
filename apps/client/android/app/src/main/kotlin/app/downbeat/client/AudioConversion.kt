package app.downbeat.client

import java.io.File

data class AudioConversionPlan(
    val output: File,
    val requiresConversion: Boolean,
)

object AudioConversion {
    fun plan(source: File): AudioConversionPlan {
        if (source.extension.equals("mp3", ignoreCase = true)) {
            return AudioConversionPlan(source, requiresConversion = false)
        }
        return AudioConversionPlan(
            File(source.parentFile, source.nameWithoutExtension + ".mp3"),
            requiresConversion = true,
        )
    }
}
