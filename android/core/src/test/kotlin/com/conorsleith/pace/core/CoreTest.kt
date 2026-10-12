package com.conorsleith.pace.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class TimeFormatTest {
    @Test fun formats() {
        listOf(
            0.0 to "0.0",
            9.94 to "9.9",
            9.96 to "10.0",
            59.96 to "1:00.0",
            85.75 to "1:25.8",
            3599.96 to "1:00:00.0",
            7375.686 to "2:02:55.7",
        ).forEach { (seconds, expected) -> assertEquals(expected, TimeFormat.string(seconds)) }
    }

    @Test fun componentsRoundTrip() {
        val c = TimeComponents(2, 2, 55, 7)
        assertEquals(c, TimeComponents.of(c.totalSeconds))
    }
}

class PresetTest {
    @Test fun allPresetsPresent() {
        assertEquals(
            listOf("200m", "400m", "800m", "1000m", "1500m", "1 mi", "3000m", "5k", "10k", "15k", "10 mi", "Half", "Marathon", "50k"),
            PresetDistance.entries.map { it.label },
        )
    }

    @Test fun matchesDistance() {
        assertEquals(PresetDistance.MILE, PresetDistance.of(Distance(1.0, DistanceUnit.MI)))
        assertNull(PresetDistance.of(Distance(1234.0)))
    }
}

class RaceSplitTest {
    @Test fun trackSplitCounts() {
        assertEquals(13, RaceKind.M5000.splitPoints(SplitType.LAPS).size)
        assertEquals(25, RaceKind.M10000.splitPoints(SplitType.LAPS).size)
        assertEquals("409m", RaceKind.MILE.splitPoints(SplitType.LAPS).first().label)
    }

    @Test fun marathonMileSplits() {
        val points = RaceKind.MARATHON.splitPoints(SplitType.MILE)
        assertEquals(27, points.size)
        assertEquals("26 mi", points[25].label)
        assertEquals("Finish", points.last().label)
    }
}

class TrackedRaceTest {
    private fun marathon() = TrackedRace(kind = RaceKind.MARATHON, label = RaceLabel.MEN)

    @Test fun title() {
        assertEquals("Marathon · Men", marathon().title)
        assertEquals("1500m", TrackedRace(kind = RaceKind.M1500).title)
        assertEquals("Heat 2", TrackedRace(kind = RaceKind.M1500, customName = "Heat 2").title)
    }

    @Test fun story3ProjectsFinish() {
        val race = marathon().record(874.0, 0)!!
        assertEquals("2:02:55.7", TimeFormat.string(race.projectedFinishAtAverage!!))
        assertEquals(1, race.selectedPointIndex)
    }

    @Test fun lastSegmentProjectionDiverges() {
        val race = marathon().record(874.0, 0)!!.record(1734.0, 1)!!
        assertEquals("14:20.0", TimeFormat.string(race.analysis.last().segmentTime))
        assertEquals("2:01:56.6", TimeFormat.string(race.projectedFinishAtAverage!!))
        assertEquals("2:01:11.5", TimeFormat.string(race.projectedFinishAtLastSegment!!))
    }

    @Test fun prefills() {
        assertEquals("29:08.0", TimeFormat.string(marathon().record(874.0, 0)!!.projectedElapsed(1)))
        assertEquals("45.0", TimeFormat.string(TrackedRace(kind = RaceKind.M1500).projectedElapsed(0)))
    }

    @Test fun skippedSplitInterpolates() {
        val race = marathon().record(874.0, 0)!!.record(2620.0, 2)!!
        assertNull(race.splitAt(1))
        assertEquals("29:07.0", TimeFormat.string(race.projectedElapsed(1)))
    }

    @Test fun rejectsOutOfOrderTimes() {
        val race = marathon().record(874.0, 0)!!.record(2620.0, 2)!!
        assertNull(race.record(800.0, 1))
        assertNull(race.record(2700.0, 1))
        assertNotNull(race.record(1745.0, 1))
    }

    @Test fun undoLast() {
        val race = marathon().record(874.0, 0)!!.record(1734.0, 1)!!.undoLast()
        assertEquals(1, race.splits.size)
        assertEquals(1, race.selectedPointIndex)
    }

    @Test fun trackLapEquivalent() {
        val a = TrackedRace(kind = RaceKind.M1500).record(43.5, 0)!!.record(101.5, 1)!!.analysis
        assertEquals("58.0", TimeFormat.string(a[0].segmentPace.timeFor(Distance(400.0))))
        assertEquals("58.0", TimeFormat.string(a[1].segmentPace.timeFor(Distance(400.0))))
    }

    @Test fun finishes() {
        var race = TrackedRace(kind = RaceKind.M800)
        listOf(26.0, 53.0, 80.0, 105.0).forEachIndexed { i, t -> race = race.record(t, i)!! }
        assertTrue(race.isFinished)
        assertFalse(race.canRecord(110.0, 4))
    }
}

class RaceStoreTest {
    @Test fun addRemoveSelect() {
        val men = TrackedRace(kind = RaceKind.MARATHON, label = RaceLabel.MEN)
        val women = TrackedRace(kind = RaceKind.MARATHON, label = RaceLabel.WOMEN)
        val store = RaceStore().add(men).add(women)
        assertEquals(women.id, store.selectedId)
        assertEquals(men.id, store.remove(women.id).selectedId)
    }

    @Test fun persistsRoundTrip() {
        val race = TrackedRace(kind = RaceKind.HALF, splitType = SplitType.MILE, label = RaceLabel.WOMEN).record(290.0, 0)!!
        val store = RaceStore().add(race).add(TrackedRace(kind = RaceKind.M5000))
        assertEquals(store, RaceStore.decoded(store.encoded()))
    }
}

class CalculationTest {
    private val k5 = PresetDistance.K5.distance

    @Test fun story1PaceThenDistance() {
        val calc = Calculation(k5, 1200.0).withPace(Pace.per(DistanceUnit.MI, 345.0)).withDistance(PresetDistance.M400.distance)
        assertEquals(Calculation.Field.TIME, calc.calculated)
        assertEquals("1:25.7", TimeFormat.string(calc.time))
    }

    @Test fun story2DistanceThenTime() {
        val calc = Calculation(k5, 1200.0).withDistance(PresetDistance.M800.distance).withTime(165.0)
        assertEquals(Calculation.Field.PACE, calc.calculated)
        assertEquals("5:31.9", TimeFormat.string(calc.pace.secondsPer(DistanceUnit.MI)))
    }

    @Test fun changingDistanceKeepsLastSetField() {
        val calc = Calculation(k5, 874.0).withDistance(PresetDistance.K10.distance)
        assertEquals(874.0, calc.time)
        val byPace = calc.withPace(Pace.per(DistanceUnit.KM, 180.0)).withDistance(k5)
        assertEquals("15:00.0", TimeFormat.string(byPace.time))
    }

    @Test fun story3ProjectToMarathon() {
        val calc = Calculation(k5, 874.0).withDistanceKeepingPace(PresetDistance.MARATHON.distance)
        assertEquals(Calculation.Field.PACE, calc.fixed)
        assertEquals("2:02:55.7", TimeFormat.string(calc.time))
    }
}
