import Foundation

/// A unit used for pace, speed and custom distances.
public enum DistanceUnit: String, Codable, CaseIterable, Sendable {
    case mi
    case km

    public var meters: Double {
        switch self {
        case .mi: Distance.metersPerMile
        case .km: 1000
        }
    }

    /// Short label for pace, e.g. "/mi".
    public var paceSuffix: String { "/\(rawValue)" }

    /// Speed label, e.g. "mph".
    public var speedLabel: String {
        switch self {
        case .mi: "mph"
        case .km: "km/h"
        }
    }

    public var other: DistanceUnit { self == .mi ? .km : .mi }
}

/// A distance, stored in meters.
public struct Distance: Hashable, Codable, Sendable {
    public static let metersPerMile = 1609.344
    public static let halfMarathonMeters = 21097.5
    public static let marathonMeters = 42195.0

    public var meters: Double

    public init(meters: Double) {
        self.meters = meters
    }

    public init(_ value: Double, _ unit: DistanceUnit) {
        self.meters = value * unit.meters
    }

    public func value(in unit: DistanceUnit) -> Double {
        meters / unit.meters
    }
}

/// Common race and training distances.
public enum PresetDistance: String, Codable, CaseIterable, Identifiable, Sendable {
    case m200, m400, m800, m1000, m1500, mile, m3000
    case k5, k10, k15, mi10, half, marathon, k50

    public var id: String { rawValue }

    public var distance: Distance { Distance(meters: meters) }

    public var meters: Double {
        switch self {
        case .m200: 200
        case .m400: 400
        case .m800: 800
        case .m1000: 1000
        case .m1500: 1500
        case .mile: Distance.metersPerMile
        case .m3000: 3000
        case .k5: 5000
        case .k10: 10_000
        case .k15: 15_000
        case .mi10: 10 * Distance.metersPerMile
        case .half: Distance.halfMarathonMeters
        case .marathon: Distance.marathonMeters
        case .k50: 50_000
        }
    }

    public var name: String {
        switch self {
        case .m200: "200m"
        case .m400: "400m"
        case .m800: "800m"
        case .m1000: "1000m"
        case .m1500: "1500m"
        case .mile: "1 mi"
        case .m3000: "3000m"
        case .k5: "5k"
        case .k10: "10k"
        case .k15: "15k"
        case .mi10: "10 mi"
        case .half: "Half"
        case .marathon: "Marathon"
        case .k50: "50k"
        }
    }

    /// The preset matching a distance, if any.
    public init?(distance: Distance) {
        guard let match = Self.allCases.first(where: { abs($0.meters - distance.meters) < 0.001 }) else {
            return nil
        }
        self = match
    }
}
