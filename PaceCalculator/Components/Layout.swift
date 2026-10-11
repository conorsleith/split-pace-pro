import PaceCore
import SwiftUI

extension EnvironmentValues {
    /// True on iPad (regular width) and macOS, where input and results sit side by side.
    var isWideLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .regular
        #else
        true
        #endif
    }
}

/// mi / km toggle, persisted across launches.
struct UnitToggle: View {
    @Binding var unit: DistanceUnit

    var body: some View {
        Picker("Units", selection: $unit) {
            ForEach(DistanceUnit.allCases, id: \.self) { u in
                Text(u.rawValue).tag(u)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }
}

extension Pace {
    var isValid: Bool { secondsPerMeter.isFinite && secondsPerMeter > 0 }
}

/// Formats a time, or a dash when the pace is not usable.
func timeText(_ seconds: Double?) -> String {
    guard let seconds, seconds.isFinite, seconds > 0 else { return "—" }
    return TimeFormat.string(seconds)
}
