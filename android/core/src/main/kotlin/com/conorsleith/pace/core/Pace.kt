package com.conorsleith.pace.core

import kotlinx.serialization.Serializable

/** A running pace, stored as seconds per meter. */
@Serializable
data class Pace(val secondsPerMeter: Double) {
    /** Time to cover [distance] at this pace. */
    fun timeFor(distance: Distance): Double = secondsPerMeter * distance.meters

    /** Seconds per mile or km. */
    fun secondsPer(unit: DistanceUnit): Double = secondsPerMeter * unit.meters

    /** Speed in mph or km/h. */
    fun speedIn(unit: DistanceUnit): Double =
        if (secondsPerMeter > 0) 3600 / secondsPer(unit) else 0.0

    val isValid: Boolean get() = secondsPerMeter.isFinite() && secondsPerMeter > 0

    companion object {
        /** Pace from covering [distance] in [seconds]. */
        fun of(seconds: Double, distance: Distance) = Pace(seconds / distance.meters)

        /** Pace given as time per unit, e.g. 345 seconds per mile. */
        fun per(unit: DistanceUnit, seconds: Double) = Pace(seconds / unit.meters)
    }
}
