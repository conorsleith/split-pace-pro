import PaceCore
import SwiftUI

/// Time entry as h : mm : ss . t (hours optional).
struct DurationInput: View {
    @Binding var seconds: Double
    var showsHours = true

    var body: some View {
        NumberColumnsInput(columns: columns, values: values)
    }

    private var columns: [NumberColumn] {
        var c: [NumberColumn] = []
        if showsHours {
            c.append(NumberColumn(range: 0...23, separator: ":", accessibilityLabel: "hours"))
        }
        c += [
            NumberColumn(range: 0...59, digits: showsHours ? 2 : 1, separator: ":", wraps: true, accessibilityLabel: "minutes"),
            NumberColumn(range: 0...59, digits: 2, separator: ".", wraps: true, accessibilityLabel: "seconds"),
            NumberColumn(range: 0...9, wraps: true, accessibilityLabel: "tenths"),
        ]
        return c
    }

    private var values: Binding<[Int]> {
        Binding(
            get: {
                let t = TimeComponents(totalSeconds: seconds)
                let minutes = showsHours ? t.minutes : min(59, t.hours * 60 + t.minutes)
                return (showsHours ? [t.hours] : []) + [minutes, t.seconds, t.tenths]
            },
            set: { v in
                let offset = showsHours ? 1 : 0
                let t = TimeComponents(
                    hours: showsHours ? v[0] : 0,
                    minutes: v[offset],
                    seconds: v[offset + 1],
                    tenths: v[offset + 2]
                )
                seconds = t.totalSeconds
            }
        )
    }
}

/// Distance entry as whole . hundredths in the given unit.
struct DecimalDistanceInput: View {
    @Binding var distance: Distance
    var unit: DistanceUnit

    var body: some View {
        HStack(spacing: 8) {
            NumberColumnsInput(
                columns: [
                    NumberColumn(range: 0...200, separator: ".", accessibilityLabel: unit == .mi ? "miles" : "kilometers"),
                    NumberColumn(range: 0...99, digits: 2, wraps: true, accessibilityLabel: "hundredths"),
                ],
                values: values
            )
            Text(unit.rawValue).font(.title3).foregroundStyle(.secondary)
        }
    }

    private var values: Binding<[Int]> {
        Binding(
            get: {
                let hundredths = Int((distance.value(in: unit) * 100).rounded())
                return [min(200, hundredths / 100), hundredths % 100]
            },
            set: { v in
                distance = Distance(Double(v[0]) + Double(v[1]) / 100, unit)
            }
        )
    }
}
