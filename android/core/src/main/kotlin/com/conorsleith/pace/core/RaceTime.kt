package com.conorsleith.pace.core

/** Elapsed time broken into display components, rounded to tenths of a second. */
data class TimeComponents(
    val hours: Int = 0,
    val minutes: Int = 0,
    val seconds: Int = 0,
    val tenths: Int = 0,
) {
    val totalSeconds: Double
        get() = (hours * 3600 + minutes * 60 + seconds) + tenths / 10.0

    companion object {
        /** Rounds [totalSeconds] to the nearest tenth (half away from zero, like the iOS app). */
        fun of(totalSeconds: Double): TimeComponents {
            val totalTenths = maxOf(0L, Math.round(totalSeconds * 10)).toInt()
            return TimeComponents(
                hours = totalTenths / 36_000,
                minutes = (totalTenths / 600) % 60,
                seconds = (totalTenths / 10) % 60,
                tenths = totalTenths % 10,
            )
        }

        /** [totalSeconds] rounded to what the wheels can show. */
        fun roundToTenths(totalSeconds: Double): Double = of(totalSeconds).totalSeconds
    }
}

object TimeFormat {
    /** Formats seconds as `h:mm:ss.t`, `m:ss.t` or `s.t`, rounded to tenths. */
    fun string(totalSeconds: Double): String {
        val c = TimeComponents.of(totalSeconds)
        return when {
            c.hours > 0 -> "${c.hours}:${pad(c.minutes)}:${pad(c.seconds)}.${c.tenths}"
            c.minutes > 0 -> "${c.minutes}:${pad(c.seconds)}.${c.tenths}"
            else -> "${c.seconds}.${c.tenths}"
        }
    }

    private fun pad(n: Int) = n.toString().padStart(2, '0')
}
