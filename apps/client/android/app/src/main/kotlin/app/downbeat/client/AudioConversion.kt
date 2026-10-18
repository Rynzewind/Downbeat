package app.downbeat.client

import java.io.File

data class AudioConversionPlan(
    val output: File,
    val publishedOutput: File,
    val requiresConversion: Boolean,
)

object AudioConversion {
    fun plan(source: File, requiresMetadataRewrite: Boolean = false): AudioConversionPlan {
        if (source.extension.equals("mp3", ignoreCase = true) && !requiresMetadataRewrite) {
            return AudioConversionPlan(source, source, requiresConversion = false)
        }
        if (source.extension.equals("mp3", ignoreCase = true)) {
            return AudioConversionPlan(
                File(source.parentFile, source.nameWithoutExtension + ".tagged.mp3"),
                source,
                requiresConversion = true,
            )
        }
        val output = File(source.parentFile, source.nameWithoutExtension + ".mp3")
        return AudioConversionPlan(
            output,
            output,
            requiresConversion = true,
        )
    }
}
