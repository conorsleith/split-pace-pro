import Foundation

/// Distance, time and pace, where any two determine the third.
///
/// Distance is always an input. Of time and pace, whichever was set most
/// recently stays fixed and the other is calculated. Changing the distance
/// therefore recalculates whichever of time or pace was not set last.
public struct Calculation: Hashable, Sendable {
    public enum Field: Hashable, Sendable {
        case time
        case pace
    }

    public var distance: Distance
    /// The field the user set most recently; the other one is calculated.
    public private(set) var fixed: Field
    private var fixedTime: Double
    private var fixedPace: Pace

    public init(distance: Distance, time: Double) {
        self.distance = distance
        self.fixed = .time
        self.fixedTime = time
        self.fixedPace = Pace(seconds: time, distance: distance)
    }

    public var calculated: Field { fixed == .time ? .pace : .time }

    public var time: Double {
        fixed == .time ? fixedTime : fixedPace.time(for: distance)
    }

    public var pace: Pace {
        fixed == .pace ? fixedPace : Pace(seconds: fixedTime, distance: distance)
    }

    public mutating func setTime(_ seconds: Double) {
        fixedTime = seconds
        fixed = .time
    }

    public mutating func setPace(_ pace: Pace) {
        fixedPace = pace
        fixed = .pace
    }

    /// Moves to another distance at the current pace, e.g. "what would a
    /// marathon be at this pace?"
    public mutating func setDistanceKeepingPace(_ newDistance: Distance) {
        setPace(pace)
        distance = newDistance
    }
}
