import Foundation
import Testing
@testable import PaceCore

/// Runs the platform-neutral vectors in fixtures.json.
struct FixtureTests {
    struct Fixtures: Decodable {
        struct PaceToTime: Decodable { var name: String; var paceSeconds: Double; var unit: DistanceUnit; var meters: Double; var expected: String }
        struct TimeToPace: Decodable { var name: String; var seconds: Double; var meters: Double; var unit: DistanceUnit; var expected: String }
        struct Projection: Decodable { var name: String; var seconds: Double; var meters: Double; var targetMeters: Double; var expected: String }
        struct Speed: Decodable { var name: String; var paceSeconds: Double; var paceUnit: DistanceUnit; var speedUnit: DistanceUnit; var expected: Double }
        struct Splits: Decodable { var race: RaceKind; var splitType: SplitType; var meters: [Double] }

        var paceToTime: [PaceToTime]
        var timeToPace: [TimeToPace]
        var projection: [Projection]
        var speed: [Speed]
        var splitPoints: [Splits]
    }

    static let fixtures: Fixtures = {
        let url = Bundle.module.url(forResource: "fixtures", withExtension: "json")!
        return try! JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
    }()

    @Test func paceToTime() {
        for f in Self.fixtures.paceToTime {
            let time = Pace(secondsPer: f.unit, f.paceSeconds).time(for: Distance(meters: f.meters))
            #expect(TimeFormat.string(time) == f.expected, "\(f.name)")
        }
    }

    @Test func timeToPace() {
        for f in Self.fixtures.timeToPace {
            let pace = Pace(seconds: f.seconds, distance: Distance(meters: f.meters))
            #expect(TimeFormat.string(pace.seconds(per: f.unit)) == f.expected, "\(f.name)")
        }
    }

    @Test func projection() {
        for f in Self.fixtures.projection {
            let pace = Pace(seconds: f.seconds, distance: Distance(meters: f.meters))
            let time = pace.time(for: Distance(meters: f.targetMeters))
            #expect(TimeFormat.string(time) == f.expected, "\(f.name)")
        }
    }

    @Test func speed() {
        for f in Self.fixtures.speed {
            let speed = Pace(secondsPer: f.paceUnit, f.paceSeconds).speed(in: f.speedUnit)
            #expect(abs(speed - f.expected) < 0.0001, "\(f.name)")
        }
    }

    @Test func splitPoints() {
        for f in Self.fixtures.splitPoints {
            let meters = f.race.splitPoints(f.splitType).map(\.meters)
            #expect(meters.count == f.meters.count, "\(f.race)")
            for (a, b) in zip(meters, f.meters) {
                #expect(abs(a - b) < 0.001, "\(f.race) \(a) != \(b)")
            }
        }
    }
}
