import Foundation

/// Elapsed time broken into display components, rounded to tenths of a second.
public struct TimeComponents: Hashable, Sendable {
    public var hours: Int
    public var minutes: Int
    public var seconds: Int
    public var tenths: Int

    public init(hours: Int = 0, minutes: Int = 0, seconds: Int = 0, tenths: Int = 0) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.tenths = tenths
    }

    /// Rounds `totalSeconds` to the nearest tenth.
    public init(totalSeconds: Double) {
        let totalTenths = max(0, Int((totalSeconds * 10).rounded()))
        hours = totalTenths / 36_000
        minutes = (totalTenths / 600) % 60
        seconds = (totalTenths / 10) % 60
        tenths = totalTenths % 10
    }

    public var totalSeconds: Double {
        Double(hours * 3600 + minutes * 60 + seconds) + Double(tenths) / 10
    }
}

public enum TimeFormat {
    /// Formats seconds as `h:mm:ss.t`, `m:ss.t` or `s.t`, rounded to tenths.
    public static func string(_ totalSeconds: Double) -> String {
        let c = TimeComponents(totalSeconds: totalSeconds)
        if c.hours > 0 {
            return "\(c.hours):\(pad(c.minutes)):\(pad(c.seconds)).\(c.tenths)"
        }
        if c.minutes > 0 {
            return "\(c.minutes):\(pad(c.seconds)).\(c.tenths)"
        }
        return "\(c.seconds).\(c.tenths)"
    }

    private static func pad(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }
}
