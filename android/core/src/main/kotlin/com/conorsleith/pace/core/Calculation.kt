package com.conorsleith.pace.core

/**
 * Distance, time and pace, where any two determine the third.
 *
 * Distance is always an input. Of time and pace, whichever was set most
 * recently stays fixed and the other is calculated. Changing the distance
 * therefore recalculates whichever of time or pace was not set last.
 */
data class Calculation private constructor(
    val distance: Distance,
    /** The field the user set most recently; the other one is calculated. */
    val fixed: Field,
    private val fixedTime: Double,
    private val fixedPace: Pace,
) {
    enum class Field { TIME, PACE }

    constructor(distance: Distance, time: Double) :
        this(distance, Field.TIME, time, Pace.of(time, distance))

    val calculated: Field get() = if (fixed == Field.TIME) Field.PACE else Field.TIME

    val time: Double get() = if (fixed == Field.TIME) fixedTime else fixedPace.timeFor(distance)

    val pace: Pace get() = if (fixed == Field.PACE) fixedPace else Pace.of(fixedTime, distance)

    fun withDistance(distance: Distance) = copy(distance = distance)

    fun withTime(seconds: Double) = copy(fixed = Field.TIME, fixedTime = seconds)

    fun withPace(pace: Pace) = copy(fixed = Field.PACE, fixedPace = pace)

    /** Moves to another distance at the current pace, e.g. "what would a marathon be at this pace?" */
    fun withDistanceKeepingPace(distance: Distance) = withPace(pace).withDistance(distance)
}
