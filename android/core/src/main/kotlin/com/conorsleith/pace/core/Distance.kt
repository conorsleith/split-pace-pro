package com.conorsleith.pace.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** A unit used for pace, speed and custom distances. */
@Serializable
enum class DistanceUnit(val label: String, val meters: Double) {
    @SerialName("mi") MI("mi", Distance.METERS_PER_MILE),
    @SerialName("km") KM("km", 1000.0);

    /** Short label for pace, e.g. "/mi". */
    val paceSuffix: String get() = "/$label"

    /** Speed label, e.g. "mph". */
    val speedLabel: String get() = if (this == MI) "mph" else "km/h"

    val other: DistanceUnit get() = if (this == MI) KM else MI

    companion object {
        fun fromLabel(label: String): DistanceUnit = entries.first { it.label == label }
    }
}

/** A distance, stored in meters. */
@Serializable
data class Distance(val meters: Double) {
    constructor(value: Double, unit: DistanceUnit) : this(value * unit.meters)

    fun valueIn(unit: DistanceUnit): Double = meters / unit.meters

    companion object {
        const val METERS_PER_MILE = 1609.344
        const val HALF_MARATHON_METERS = 21097.5
        const val MARATHON_METERS = 42195.0
    }
}

/** Common race and training distances. */
enum class PresetDistance(val meters: Double, val label: String) {
    M200(200.0, "200m"),
    M400(400.0, "400m"),
    M800(800.0, "800m"),
    M1000(1000.0, "1000m"),
    M1500(1500.0, "1500m"),
    MILE(Distance.METERS_PER_MILE, "1 mi"),
    M3000(3000.0, "3000m"),
    K5(5000.0, "5k"),
    K10(10_000.0, "10k"),
    K15(15_000.0, "15k"),
    MI10(10 * Distance.METERS_PER_MILE, "10 mi"),
    HALF(Distance.HALF_MARATHON_METERS, "Half"),
    MARATHON(Distance.MARATHON_METERS, "Marathon"),
    K50(50_000.0, "50k");

    val distance: Distance get() = Distance(meters)

    companion object {
        /** The preset matching a distance, if any. */
        fun of(distance: Distance): PresetDistance? =
            entries.firstOrNull { kotlin.math.abs(it.meters - distance.meters) < 0.001 }
    }
}
