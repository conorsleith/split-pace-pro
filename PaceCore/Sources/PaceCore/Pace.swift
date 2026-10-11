import Foundation

/// A running pace, stored as seconds per meter.
public struct Pace: Hashable, Codable, Sendable {
    public var secondsPerMeter: Double

    public init(secondsPerMeter: Double) {
        self.secondsPerMeter = secondsPerMeter
    }

    /// Pace from covering `distance` in `seconds`.
    public init(seconds: Double, distance: Distance) {
        self.secondsPerMeter = seconds / distance.meters
    }

    /// Pace given as time per unit, e.g. 345 seconds per mile.
    public init(secondsPer unit: DistanceUnit, _ seconds: Double) {
        self.secondsPerMeter = seconds / unit.meters
    }

    /// Time to cover `distance` at this pace.
    public func time(for distance: Distance) -> Double {
        secondsPerMeter * distance.meters
    }

    /// Seconds per mile or km.
    public func seconds(per unit: DistanceUnit) -> Double {
        secondsPerMeter * unit.meters
    }

    /// Speed in mph or km/h.
    public func speed(in unit: DistanceUnit) -> Double {
        guard secondsPerMeter > 0 else { return 0 }
        return 3600 / seconds(per: unit)
    }
}
