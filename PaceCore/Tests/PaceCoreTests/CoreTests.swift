import Foundation
import Testing
@testable import PaceCore

struct TimeFormatTests {
    @Test(arguments: [
        (0.0, "0.0"),
        (9.94, "9.9"),
        (9.96, "10.0"),
        (59.96, "1:00.0"),
        (85.75, "1:25.8"),
        (3599.96, "1:00:00.0"),
        (7375.686, "2:02:55.7"),
    ])
    func formats(seconds: Double, expected: String) {
        #expect(TimeFormat.string(seconds) == expected)
    }

    @Test func componentsRoundTrip() {
        let c = TimeComponents(hours: 2, minutes: 2, seconds: 55, tenths: 7)
        #expect(TimeComponents(totalSeconds: c.totalSeconds) == c)
    }
}

struct PresetTests {
    @Test func allPresetsPresent() {
        #expect(PresetDistance.allCases.map(\.name) == [
            "200m", "400m", "800m", "1000m", "1500m", "1 mi", "3000m",
            "5k", "10k", "15k", "10 mi", "Half", "Marathon", "50k",
        ])
    }

    @Test func matchesDistance() {
        #expect(PresetDistance(distance: Distance(1, .mi)) == .mile)
        #expect(PresetDistance(distance: Distance(meters: 1234)) == nil)
    }
}

struct RaceSplitTests {
    @Test func trackSplitCounts() {
        #expect(RaceKind.m5000.splitPoints(.laps).count == 13)
        #expect(RaceKind.m5000.splitPoints(.laps).first?.meters == 200)
        #expect(RaceKind.m10000.splitPoints(.laps).count == 25)
        #expect(RaceKind.mile.splitPoints(.laps).first?.label == "409m")
    }

    @Test func marathonMileSplits() {
        let points = RaceKind.marathon.splitPoints(.mile)
        #expect(points.count == 27)
        #expect(points[25].label == "26 mi")
        #expect(points.last?.label == "Finish")
    }

    @Test func roadSplitOptions() {
        #expect(RaceKind.marathon.splitTypes == [.km5, .mile])
        #expect(RaceKind.road10k.splitTypes == [.km1, .mile])
        #expect(RaceKind.m1500.splitTypes == [.laps])
    }
}

struct TrackedRaceTests {
    /// Marathon with 5k splits: 0=5k, 1=10k, 2=15k, 3=20k, 4=Half, ...
    func marathon() -> TrackedRace {
        TrackedRace(kind: .marathon, label: .men)
    }

    @Test func title() {
        #expect(marathon().title == "Marathon · Men")
        #expect(TrackedRace(kind: .m1500).title == "1500m")
        #expect(TrackedRace(kind: .m1500, customName: "Heat 2").title == "Heat 2")
    }

    @Test func story3ProjectsFinish() {
        var race = marathon()
        let ok1 = race.record(874, at: 0)
        #expect(ok1)
        #expect(TimeFormat.string(race.projectedFinishAtAverage!) == "2:02:55.7")
        #expect(TimeFormat.string(race.projectedFinishAtLastSegment!) == "2:02:55.7")
        #expect(race.selectedPointIndex == 1)
    }

    @Test func lastSegmentProjectionDiverges() {
        var race = marathon()
        race.record(874, at: 0)   // 5k 14:34
        race.record(1734, at: 1)  // 10k 28:54 → last 5k 14:20
        let last = race.analysis.last!
        #expect(TimeFormat.string(last.segmentTime) == "14:20.0")
        // Average: 1734s/10k. Last segment: 860s/5k for the remaining 32.195k.
        #expect(TimeFormat.string(race.projectedFinishAtAverage!) == "2:01:56.6")
        #expect(TimeFormat.string(race.projectedFinishAtLastSegment!) == "2:01:11.5")
    }

    @Test func prefillsAtAveragePace() {
        var race = marathon()
        race.record(874, at: 0)
        #expect(TimeFormat.string(race.projectedElapsed(at: 1)) == "29:08.0")
    }

    @Test func prefillsUsingDefaultPaceBeforeAnySplits() {
        let race = TrackedRace(kind: .m1500)
        // 60s per 400 → 300m in 45s
        #expect(TimeFormat.string(race.projectedElapsed(at: 0)) == "45.0")
    }

    @Test func skippedSplitInterpolates() {
        var race = marathon()
        race.record(874, at: 0)
        race.record(2620, at: 2)  // missed 10k, 15k at 43:40
        #expect(race.split(at: 1) == nil)
        #expect(TimeFormat.string(race.projectedElapsed(at: 1)) == "29:07.0")
        #expect(race.analysis[1].segmentMeters == 10_000)
    }

    @Test func rejectsOutOfOrderTimes() {
        var race = marathon()
        race.record(874, at: 0)
        race.record(2620, at: 2)
        let ok2 = race.record(800, at: 1)   // before the 5k time
        #expect(!ok2)
        let ok3 = race.record(2700, at: 1)  // after the 15k time
        #expect(!ok3)
        let ok4 = race.record(1745, at: 1)
        #expect(ok4)
    }

    @Test func editReplacesSplit() {
        var race = marathon()
        race.record(874, at: 0)
        race.record(880, at: 0)
        #expect(race.splits == [RecordedSplit(pointIndex: 0, elapsed: 880)])
    }

    @Test func undoLast() {
        var race = marathon()
        race.record(874, at: 0)
        race.record(1734, at: 1)
        race.undoLast()
        #expect(race.splits.count == 1)
        #expect(race.selectedPointIndex == 1)
    }

    @Test func trackLapEquivalent() {
        var race = TrackedRace(kind: .m1500)
        race.record(43.5, at: 0)  // 300m
        race.record(101.5, at: 1) // 700m → 58.0 lap
        let a = race.analysis
        #expect(TimeFormat.string(a[0].segmentPace.time(for: Distance(meters: 400))) == "58.0")
        #expect(TimeFormat.string(a[1].segmentPace.time(for: Distance(meters: 400))) == "58.0")
    }

    @Test func finishes() {
        var race = TrackedRace(kind: .m800)
        for (i, t) in [26.0, 53.0, 80.0, 105.0].enumerated() {
            race.record(t, at: i)
        }
        #expect(race.isFinished)
        #expect(race.selectedPointIndex == 3)
    }
}

struct RaceStoreTests {
    @Test func addRemoveSelect() {
        var store = RaceStore()
        let men = TrackedRace(kind: .marathon, label: .men)
        let women = TrackedRace(kind: .marathon, label: .women)
        store.add(men)
        store.add(women)
        #expect(store.selectedID == women.id)
        store.remove(id: women.id)
        #expect(store.selectedID == men.id)
    }

    @Test func persistsRoundTrip() throws {
        var store = RaceStore()
        var race = TrackedRace(kind: .half, splitType: .mile, label: .women)
        race.record(290, at: 0)
        store.add(race)
        store.add(TrackedRace(kind: .m5000))
        let decoded = try RaceStore.decoded(from: store.encoded())
        #expect(decoded == store)
    }
}

struct CalculationTests {
    @Test func story1PaceThenDistance() {
        var calc = Calculation(distance: PresetDistance.k5.distance, time: 1200)
        calc.setPace(Pace(secondsPer: .mi, 345))
        calc.distance = PresetDistance.m400.distance
        #expect(calc.calculated == .time)
        #expect(TimeFormat.string(calc.time) == "1:25.7")
    }

    @Test func story2DistanceThenTime() {
        var calc = Calculation(distance: PresetDistance.k5.distance, time: 1200)
        calc.distance = PresetDistance.m800.distance
        calc.setTime(165)
        #expect(calc.calculated == .pace)
        #expect(TimeFormat.string(calc.pace.seconds(per: .mi)) == "5:31.9")
    }

    @Test func changingDistanceKeepsLastSetField() {
        var calc = Calculation(distance: PresetDistance.k5.distance, time: 874)
        calc.distance = PresetDistance.k10.distance
        // Time was set last, so it stays and the pace slows.
        #expect(calc.time == 874)

        calc.setPace(Pace(secondsPer: .km, 180))
        calc.distance = PresetDistance.k5.distance
        // Pace was set last, so it stays and the time is recalculated.
        #expect(TimeFormat.string(calc.time) == "15:00.0")
    }

    @Test func story3ProjectToMarathon() {
        var calc = Calculation(distance: PresetDistance.k5.distance, time: 874)
        calc.setDistanceKeepingPace(PresetDistance.marathon.distance)
        #expect(calc.fixed == .pace)
        #expect(TimeFormat.string(calc.time) == "2:02:55.7")
    }

    @Test func zeroTimeGivesNoPace() {
        let calc = Calculation(distance: PresetDistance.k5.distance, time: 0)
        #expect(calc.pace.secondsPerMeter == 0)
    }
}
