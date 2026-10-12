package com.conorsleith.pace.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.util.UUID

/** How splits are reported for a race. */
@Serializable
enum class SplitType(val label: String) {
    @SerialName("laps") LAPS("Laps"),
    @SerialName("km1") KM1("1k"),
    @SerialName("km5") KM5("5k"),
    @SerialName("mile") MILE("Mile"),
}

/** A point in a race where a split is reported. */
data class SplitPoint(val meters: Double, val label: String)

/** Races that can be followed in race-watching mode. */
@Serializable
enum class RaceKind(val id: String, val label: String, val meters: Double, val isTrack: Boolean) {
    @SerialName("m800") M800("m800", "800m", 800.0, true),
    @SerialName("m1500") M1500("m1500", "1500m", 1500.0, true),
    @SerialName("mile") MILE("mile", "Mile", Distance.METERS_PER_MILE, true),
    @SerialName("m3000") M3000("m3000", "3000m", 3000.0, true),
    @SerialName("m5000") M5000("m5000", "5000m", 5000.0, true),
    @SerialName("m10000") M10000("m10000", "10,000m", 10_000.0, true),
    @SerialName("road5k") ROAD5K("road5k", "5k road", 5000.0, false),
    @SerialName("road10k") ROAD10K("road10k", "10k road", 10_000.0, false),
    @SerialName("half") HALF("half", "Half marathon", Distance.HALF_MARATHON_METERS, false),
    @SerialName("marathon") MARATHON("marathon", "Marathon", Distance.MARATHON_METERS, false);

    val splitTypes: List<SplitType>
        get() = when {
            isTrack -> listOf(SplitType.LAPS)
            this == ROAD5K || this == ROAD10K -> listOf(SplitType.KM1, SplitType.MILE)
            else -> listOf(SplitType.KM5, SplitType.MILE)
        }

    val defaultSplitType: SplitType get() = splitTypes.first()

    /** Pace used to prefill split times before any splits are recorded. */
    val defaultPace: Pace
        get() = if (isTrack) Pace.of(60.0, Distance(400.0)) else Pace.per(DistanceUnit.KM, 175.0)

    /** Cumulative split points from the start, ending at the finish. */
    fun splitPoints(type: SplitType): List<SplitPoint> {
        val finish = SplitPoint(meters, "Finish")
        return when (type) {
            SplitType.LAPS -> {
                // Track splits are counted back from the finish line, so a 1500m
                // starts with 300m. A leftover stub shorter than 100m is folded
                // into the first lap, so a mile starts with 409m rather than 9m.
                val lap = if (this == M800) 200.0 else 400.0
                val points = ArrayDeque(listOf(finish))
                var m = meters - lap
                while (m >= 100) {
                    points.addFirst(SplitPoint(m, "${Math.round(m)}m"))
                    m -= lap
                }
                points.toList()
            }
            SplitType.KM1 -> evenSplits(1000.0) { "${it}k" } + finish
            SplitType.KM5 -> {
                var points = evenSplits(5000.0) { "${it * 5}k" }
                if (this == MARATHON) {
                    points = (points + SplitPoint(Distance.HALF_MARATHON_METERS, "Half")).sortedBy { it.meters }
                }
                points + finish
            }
            SplitType.MILE -> evenSplits(Distance.METERS_PER_MILE) { "$it mi" } + finish
        }
    }

    /** Splits every [interval] meters, excluding the finish. */
    private fun evenSplits(interval: Double, label: (Int) -> String): List<SplitPoint> {
        val points = mutableListOf<SplitPoint>()
        var n = 1
        while (n * interval < meters - 0.001) {
            points += SplitPoint(n * interval, label(n))
            n++
        }
        return points
    }

    companion object {
        fun fromId(id: String): RaceKind = entries.first { it.id == id }
    }
}

@Serializable
enum class RaceLabel(val label: String) {
    @SerialName("none") NONE("None"),
    @SerialName("men") MEN("Men"),
    @SerialName("women") WOMEN("Women"),
}

@Serializable
data class RecordedSplit(val pointIndex: Int, val elapsed: Double)

/** A recorded split with the segment since the previous recorded split. */
data class SplitAnalysis(
    val pointIndex: Int,
    val point: SplitPoint,
    val elapsed: Double,
    val segmentTime: Double,
    val segmentMeters: Double,
) {
    val segmentPace: Pace get() = Pace.of(segmentTime, Distance(segmentMeters))
    val averagePace: Pace get() = Pace.of(elapsed, Distance(point.meters))
}

/** Exclusive bounds for a split time: after [after], and before [before] if set. */
data class AllowedRange(val after: Double, val before: Double?)

/** A race being followed split by split. Immutable; changes return a new race. */
@Serializable
data class TrackedRace(
    val id: String = UUID.randomUUID().toString(),
    val kind: RaceKind,
    val splitType: SplitType = kind.defaultSplitType,
    val label: RaceLabel = RaceLabel.NONE,
    val customName: String? = null,
    /** Sorted by pointIndex. */
    val splits: List<RecordedSplit> = emptyList(),
    val selectedPointIndex: Int = 0,
) {
    val title: String
        get() = when {
            !customName.isNullOrEmpty() -> customName
            label == RaceLabel.NONE -> kind.label
            else -> "${kind.label} · ${label.label}"
        }

    val points: List<SplitPoint> get() = kind.splitPoints(splitType)

    val isFinished: Boolean get() = splits.lastOrNull()?.pointIndex == points.size - 1

    fun splitAt(pointIndex: Int): RecordedSplit? = splits.firstOrNull { it.pointIndex == pointIndex }

    val analysis: List<SplitAnalysis>
        get() {
            val points = points
            var previousMeters = 0.0
            var previousElapsed = 0.0
            return splits.map { split ->
                val point = points[split.pointIndex]
                SplitAnalysis(
                    pointIndex = split.pointIndex,
                    point = point,
                    elapsed = split.elapsed,
                    segmentTime = split.elapsed - previousElapsed,
                    segmentMeters = point.meters - previousMeters,
                ).also {
                    previousMeters = point.meters
                    previousElapsed = split.elapsed
                }
            }
        }

    val averagePace: Pace? get() = analysis.lastOrNull()?.averagePace
    val lastSegmentPace: Pace? get() = analysis.lastOrNull()?.segmentPace

    val projectedFinishAtAverage: Double?
        get() = averagePace?.timeFor(Distance(kind.meters))

    val projectedFinishAtLastSegment: Double?
        get() {
            val last = analysis.lastOrNull() ?: return null
            val remaining = kind.meters - last.point.meters
            return last.elapsed + last.segmentPace.timeFor(Distance(remaining))
        }

    /**
     * Expected elapsed time at a split point. Interpolates between recorded
     * splits; beyond the last one, extrapolates at the average pace.
     */
    fun projectedElapsed(pointIndex: Int): Double {
        splitAt(pointIndex)?.let { return it.elapsed }
        val points = points
        val meters = points[pointIndex].meters
        val before = splits.lastOrNull { it.pointIndex < pointIndex }
        val after = splits.firstOrNull { it.pointIndex > pointIndex }
        val startMeters = before?.let { points[it.pointIndex].meters } ?: 0.0
        val startElapsed = before?.elapsed ?: 0.0
        if (after != null) {
            val endMeters = points[after.pointIndex].meters
            val fraction = (meters - startMeters) / (endMeters - startMeters)
            return startElapsed + fraction * (after.elapsed - startElapsed)
        }
        val pace = averagePace ?: kind.defaultPace
        return startElapsed + pace.timeFor(Distance(meters - startMeters))
    }

    /** Times must increase from split to split. */
    fun allowedRange(pointIndex: Int) = AllowedRange(
        after = splits.lastOrNull { it.pointIndex < pointIndex }?.elapsed ?: 0.0,
        before = splits.firstOrNull { it.pointIndex > pointIndex }?.elapsed,
    )

    fun canRecord(elapsed: Double, pointIndex: Int): Boolean {
        if (pointIndex !in points.indices) return false
        val range = allowedRange(pointIndex)
        return elapsed > range.after && (range.before?.let { elapsed < it } ?: true)
    }

    /**
     * Records (or replaces) the split at [pointIndex] and selects the next
     * split point. Returns null if the time is out of order.
     */
    fun record(elapsed: Double, pointIndex: Int): TrackedRace? {
        if (!canRecord(elapsed, pointIndex)) return null
        val newSplits = (splits.filter { it.pointIndex != pointIndex } + RecordedSplit(pointIndex, elapsed))
            .sortedBy { it.pointIndex }
        return copy(
            splits = newSplits,
            selectedPointIndex = minOf(newSplits.last().pointIndex + 1, points.size - 1),
        )
    }

    fun removeSplit(pointIndex: Int) = copy(
        splits = splits.filter { it.pointIndex != pointIndex },
        selectedPointIndex = pointIndex,
    )

    fun undoLast(): TrackedRace = splits.lastOrNull()?.let { removeSplit(it.pointIndex) } ?: this

    fun select(pointIndex: Int) = copy(selectedPointIndex = pointIndex.coerceIn(points.indices))
}

/** All races being followed, persisted between launches. */
@Serializable
data class RaceStore(
    val races: List<TrackedRace> = emptyList(),
    val selectedId: String? = null,
) {
    val selected: TrackedRace?
        get() = races.firstOrNull { it.id == selectedId } ?: races.firstOrNull()

    fun add(race: TrackedRace) = copy(races = races + race, selectedId = race.id)

    fun remove(id: String): RaceStore {
        val remaining = races.filter { it.id != id }
        return copy(
            races = remaining,
            selectedId = if (selectedId == id) remaining.lastOrNull()?.id else selectedId,
        )
    }

    fun update(race: TrackedRace) = copy(races = races.map { if (it.id == race.id) race else it })

    fun encoded(): String = json.encodeToString(serializer(), this)

    companion object {
        // Defaults must be written, or a race's generated id would change on reload.
        private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

        fun decoded(text: String): RaceStore = json.decodeFromString(serializer(), text)
    }
}
