package app.downbeat.client

import kotlin.math.ceil
import kotlin.math.roundToInt

data class ConversionProgress(
    val overallPercent: Int?,
    val phasePercent: Int?,
    val etaSeconds: Long?,
) {
    fun message(label: String): String {
        val phase = phasePercent ?: return label
        val eta = etaSeconds?.let { " · about ${formatDuration(it)} left" }.orEmpty()
        return "$label · $phase%$eta"
    }

    companion object {
        fun calculate(
            processedMilliseconds: Long,
            durationMilliseconds: Long?,
            processingSpeed: Double?,
            startPercent: Int,
            endPercent: Int,
        ): ConversionProgress {
            if (durationMilliseconds == null || durationMilliseconds <= 0L) {
                return ConversionProgress(null, null, null)
            }
            val fraction = (processedMilliseconds.toDouble() / durationMilliseconds).coerceIn(0.0, 1.0)
            val phasePercent = (fraction * 100).roundToInt()
            val overallPercent = (startPercent + fraction * (endPercent - startPercent))
                .roundToInt()
                .coerceIn(startPercent, endPercent)
            val etaSeconds = processingSpeed
                ?.takeIf { it > 0.0 }
                ?.let { ceil((durationMilliseconds - processedMilliseconds).coerceAtLeast(0L) / 1000.0 / it).toLong() }
            return ConversionProgress(overallPercent, phasePercent, etaSeconds)
        }

        private fun formatDuration(seconds: Long): String = when {
            seconds < 60 -> "${seconds}s"
            seconds < 3600 -> "${seconds / 60}m ${seconds % 60}s"
            else -> "${seconds / 3600}h ${(seconds % 3600) / 60}m"
        }
    }
}
