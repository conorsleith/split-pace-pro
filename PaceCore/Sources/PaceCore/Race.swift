import Foundation

/// How splits are reported for a race.
public enum SplitType: String, Codable, CaseIterable, Identifiable, Sendable {
    case laps
    case km1
    case km5
    case mile

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .laps: "Laps"
        case .km1: "1k"
        case .km5: "5k"
        case .mile: "Mile"
        }
    }
}

/// A point in a race where a split is reported.
public struct SplitPoint: Hashable, Sendable {
    public var meters: Double
    public var label: String

    public init(meters: Double, label: String) {
        self.meters = meters
        self.label = label
    }
}

/// Races that can be followed in race-watching mode.
public enum RaceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case m800, m1500, mile, m3000, m5000, m10000
    case road5k, road10k, half, marathon

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .m800: "800m"
        case .m1500: "1500m"
        case .mile: "Mile"
        case .m3000: "3000m"
        case .m5000: "5000m"
        case .m10000: "10,000m"
        case .road5k: "5k road"
        case .road10k: "10k road"
        case .half: "Half marathon"
        case .marathon: "Marathon"
        }
    }

    public var meters: Double {
        switch self {
        case .m800: 800
        case .m1500: 1500
        case .mile: Distance.metersPerMile
        case .m3000: 3000
        case .m5000, .road5k: 5000
        case .m10000, .road10k: 10_000
        case .half: Distance.halfMarathonMeters
        case .marathon: Distance.marathonMeters
        }
    }

    public var isTrack: Bool {
        switch self {
        case .m800, .m1500, .mile, .m3000, .m5000, .m10000: true
        case .road5k, .road10k, .half, .marathon: false
        }
    }

    public var splitTypes: [SplitType] {
        switch self {
        case .m800, .m1500, .mile, .m3000, .m5000, .m10000: [.laps]
        case .road5k, .road10k: [.km1, .mile]
        case .half, .marathon: [.km5, .mile]
        }
    }

    public var defaultSplitType: SplitType { splitTypes[0] }

    /// Pace used to prefill split times before any splits are recorded.
    public var defaultPace: Pace {
        isTrack ? Pace(seconds: 60, distance: Distance(meters: 400)) : Pace(secondsPer: .km, 175)
    }

    /// Cumulative split points from the start, ending at the finish.
    public func splitPoints(_ type: SplitType) -> [SplitPoint] {
        let finish = SplitPoint(meters: meters, label: "Finish")
        switch type {
        case .laps:
            // Track splits are counted back from the finish line, so a 1500m
            // starts with 300m. A leftover stub shorter than 100m is folded
            // into the first lap, so a mile starts with 409m rather than 9m.
            let lap: Double = self == .m800 ? 200 : 400
            var points = [finish]
            var m = meters - lap
            while m >= 100 {
                points.insert(SplitPoint(meters: m, label: "\(Int(m.rounded()))m"), at: 0)
                m -= lap
            }
            return points
        case .km1:
            return evenSplits(every: 1000) { "\($0)k" } + [finish]
        case .km5:
            var points = evenSplits(every: 5000) { "\($0 * 5)k" }
            if self == .marathon {
                let half = SplitPoint(meters: Distance.halfMarathonMeters, label: "Half")
                points.append(half)
                points.sort { $0.meters < $1.meters }
            }
            return points + [finish]
        case .mile:
            return evenSplits(every: Distance.metersPerMile) { "\($0) mi" } + [finish]
        }
    }

    /// Splits every `interval` meters, excluding the finish.
    private func evenSplits(every interval: Double, label: (Int) -> String) -> [SplitPoint] {
        var points: [SplitPoint] = []
        var n = 1
        while Double(n) * interval < meters - 0.001 {
            points.append(SplitPoint(meters: Double(n) * interval, label: label(n)))
            n += 1
        }
        return points
    }
}

public enum RaceLabel: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, men, women

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .none: "None"
        case .men: "Men"
        case .women: "Women"
        }
    }
}

public struct RecordedSplit: Codable, Hashable, Sendable {
    public var pointIndex: Int
    public var elapsed: Double

    public init(pointIndex: Int, elapsed: Double) {
        self.pointIndex = pointIndex
        self.elapsed = elapsed
    }
}

/// A recorded split with the segment since the previous recorded split.
public struct SplitAnalysis: Hashable, Sendable {
    public var pointIndex: Int
    public var point: SplitPoint
    public var elapsed: Double
    public var segmentTime: Double
    public var segmentMeters: Double

    public var segmentPace: Pace { Pace(seconds: segmentTime, distance: Distance(meters: segmentMeters)) }
    public var averagePace: Pace { Pace(seconds: elapsed, distance: Distance(meters: point.meters)) }
}

/// A race being followed split by split.
public struct TrackedRace: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: RaceKind
    public var splitType: SplitType
    public var label: RaceLabel
    public var customName: String?
    /// Sorted by `pointIndex`.
    public private(set) var splits: [RecordedSplit]
    public var selectedPointIndex: Int

    public init(
        id: UUID = UUID(),
        kind: RaceKind,
        splitType: SplitType? = nil,
        label: RaceLabel = .none,
        customName: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.splitType = splitType ?? kind.defaultSplitType
        self.label = label
        self.customName = customName
        self.splits = []
        self.selectedPointIndex = 0
    }

    public var title: String {
        if let customName, !customName.isEmpty { return customName }
        return label == .none ? kind.name : "\(kind.name) · \(label.name)"
    }

    public var points: [SplitPoint] { kind.splitPoints(splitType) }

    public var isFinished: Bool { splits.last?.pointIndex == points.count - 1 }

    public func split(at pointIndex: Int) -> RecordedSplit? {
        splits.first { $0.pointIndex == pointIndex }
    }

    public var analysis: [SplitAnalysis] {
        let points = points
        var previousMeters = 0.0
        var previousElapsed = 0.0
        return splits.map { split in
            let point = points[split.pointIndex]
            let result = SplitAnalysis(
                pointIndex: split.pointIndex,
                point: point,
                elapsed: split.elapsed,
                segmentTime: split.elapsed - previousElapsed,
                segmentMeters: point.meters - previousMeters
            )
            previousMeters = point.meters
            previousElapsed = split.elapsed
            return result
        }
    }

    public var averagePace: Pace? { analysis.last?.averagePace }
    public var lastSegmentPace: Pace? { analysis.last?.segmentPace }

    public var projectedFinishAtAverage: Double? {
        averagePace?.time(for: Distance(meters: kind.meters))
    }

    public var projectedFinishAtLastSegment: Double? {
        guard let last = analysis.last else { return nil }
        let remaining = kind.meters - last.point.meters
        return last.elapsed + last.segmentPace.time(for: Distance(meters: remaining))
    }

    /// Expected elapsed time at a split point. Interpolates between recorded
    /// splits; beyond the last one, extrapolates at the average pace.
    public func projectedElapsed(at pointIndex: Int) -> Double {
        if let split = split(at: pointIndex) { return split.elapsed }
        let meters = points[pointIndex].meters
        let before = splits.last { $0.pointIndex < pointIndex }
        let after = splits.first { $0.pointIndex > pointIndex }
        let startMeters = before.map { points[$0.pointIndex].meters } ?? 0
        let startElapsed = before?.elapsed ?? 0
        if let after {
            let endMeters = points[after.pointIndex].meters
            let fraction = (meters - startMeters) / (endMeters - startMeters)
            return startElapsed + fraction * (after.elapsed - startElapsed)
        }
        let pace = averagePace ?? kind.defaultPace
        return startElapsed + pace.time(for: Distance(meters: meters - startMeters))
    }

    /// Times must increase from split to split. Returns the exclusive bounds
    /// for a split at `pointIndex`.
    public func allowedRange(at pointIndex: Int) -> (after: Double, before: Double?) {
        let before = splits.last { $0.pointIndex < pointIndex }?.elapsed ?? 0
        let after = splits.first { $0.pointIndex > pointIndex }?.elapsed
        return (before, after)
    }

    public func canRecord(_ elapsed: Double, at pointIndex: Int) -> Bool {
        guard points.indices.contains(pointIndex) else { return false }
        let range = allowedRange(at: pointIndex)
        return elapsed > range.after && (range.before.map { elapsed < $0 } ?? true)
    }

    /// Records (or replaces) the split at `pointIndex` and selects the next
    /// unrecorded split point. Returns false if the time is out of order.
    @discardableResult
    public mutating func record(_ elapsed: Double, at pointIndex: Int) -> Bool {
        guard canRecord(elapsed, at: pointIndex) else { return false }
        splits.removeAll { $0.pointIndex == pointIndex }
        splits.append(RecordedSplit(pointIndex: pointIndex, elapsed: elapsed))
        splits.sort { $0.pointIndex < $1.pointIndex }
        let last = splits.last!.pointIndex
        selectedPointIndex = min(last + 1, points.count - 1)
        return true
    }

    public mutating func removeSplit(at pointIndex: Int) {
        splits.removeAll { $0.pointIndex == pointIndex }
        selectedPointIndex = pointIndex
    }

    public mutating func undoLast() {
        guard let last = splits.last else { return }
        removeSplit(at: last.pointIndex)
    }
}

/// All races being followed, persisted between launches.
public struct RaceStore: Codable, Hashable, Sendable {
    public var races: [TrackedRace]
    public var selectedID: UUID?

    public init(races: [TrackedRace] = [], selectedID: UUID? = nil) {
        self.races = races
        self.selectedID = selectedID
    }

    public var selectedIndex: Int? {
        races.firstIndex { $0.id == selectedID } ?? (races.isEmpty ? nil : 0)
    }

    public mutating func add(_ race: TrackedRace) {
        races.append(race)
        selectedID = race.id
    }

    public mutating func remove(id: UUID) {
        races.removeAll { $0.id == id }
        if selectedID == id { selectedID = races.last?.id }
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decoded(from data: Data) throws -> RaceStore {
        try JSONDecoder().decode(RaceStore.self, from: data)
    }
}
