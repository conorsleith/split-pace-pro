import PaceCore
import SwiftUI

/// The row being edited.
enum CalculatorField: Hashable {
    case distance, time, pace

    var title: String {
        switch self {
        case .distance: "Distance"
        case .time: "Time"
        case .pace: "Pace"
        }
    }
}

struct CalculatorView: View {
    @AppStorage("unit") private var unit: DistanceUnit = .mi
    /// Unit for entering a custom distance, separate from the pace unit so
    /// you can enter e.g. 15 km while seeing pace per mile.
    @AppStorage("customDistanceUnit") private var customUnit: DistanceUnit = .mi
    @Environment(\.isWideLayout) private var isWide

    @State private var calc = Demo.calculation ?? Calculation(distance: PresetDistance.k5.distance, time: 20 * 60)
    @State private var editing: CalculatorField? = Demo.editing
    @State private var isCustomDistance = false

    var body: some View {
        NavigationStack {
            Group {
                if isWide {
                    HStack(spacing: 0) {
                        Form {
                            fieldRows
                            editorSection
                        }
                        .frame(minWidth: 340, idealWidth: 400, maxWidth: 460)
                        Divider()
                        SplitsTable(pace: calc.pace, highlighted: calc.distance, onSelect: selectSplit)
                    }
                } else {
                    Form {
                        fieldRows
                        editorSection
                        SplitsTable.Rows(pace: calc.pace, highlighted: calc.distance, onSelect: selectSplit)
                    }
                }
            }
            .animation(.snappy(duration: 0.25), value: editing)
            .navigationTitle("Pace")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    UnitToggle(unit: $unit)
                }
            }
        }
    }

    // MARK: Rows

    private var fieldRows: some View {
        Section {
            FieldRow(
                title: "Distance",
                value: distanceText,
                isEditing: editing == .distance,
                isCalculated: false,
                action: { toggle(.distance) }
            )
            FieldRow(
                title: "Time",
                value: timeText(calc.time),
                isEditing: editing == .time,
                isCalculated: calc.calculated == .time,
                action: { toggle(.time) }
            )
            FieldRow(
                title: "Pace",
                value: paceText(unit),
                suffix: unit.paceSuffix,
                detail: "\(paceText(unit.other)) \(unit.other.paceSuffix) · \(speedText)",
                isEditing: editing == .pace,
                isCalculated: calc.calculated == .pace,
                action: { toggle(.pace) }
            )
        }
    }

    /// The input for the row being edited, directly under the rows: mid-screen
    /// where the thumb rests, and away from the bottom edge, where a downward
    /// drag on a wheel would trigger Reachability.
    @ViewBuilder
    private var editorSection: some View {
        if let editing {
            Section {
                editor(for: editing)
            } header: {
                HStack {
                    Text(editing.title)
                    Spacer()
                    Button("Done") { self.editing = nil }
                        .fontWeight(.semibold)
                        .textCase(nil)
                }
            }
        }
    }

    private func toggle(_ field: CalculatorField) {
        editing = editing == field ? nil : field
    }

    private var distanceText: String {
        if let preset = PresetDistance(distance: calc.distance) {
            return preset.name
        }
        return String(format: "%.2f %@", calc.distance.value(in: customUnit), customUnit.rawValue)
    }

    private func paceText(_ unit: DistanceUnit) -> String {
        calc.pace.isValid ? TimeFormat.string(calc.pace.seconds(per: unit)) : "—"
    }

    private var speedText: String {
        guard calc.pace.isValid else { return "— \(unit.speedLabel)" }
        return String(format: "%.1f %@", calc.pace.speed(in: unit), unit.speedLabel)
    }

    // MARK: Editors

    @ViewBuilder
    private func editor(for field: CalculatorField) -> some View {
        switch field {
        case .distance:
            DistancePicker(distance: $calc.distance, isCustom: $isCustomDistance, customUnit: $customUnit)
        case .time:
            DurationInput(seconds: timeBinding)
        case .pace:
            DurationInput(seconds: paceBinding, showsHours: false)
        }
    }

    private var timeBinding: Binding<Double> {
        Binding(get: { calc.time }, set: { calc.setTime($0) })
    }

    private var paceBinding: Binding<Double> {
        Binding(
            get: { calc.pace.seconds(per: unit) },
            set: { calc.setPace(Pace(secondsPer: unit, $0)) }
        )
    }

    /// Tapping a split makes it the distance, keeping the current pace.
    private func selectSplit(_ distance: Distance) {
        guard calc.pace.isValid else { return }
        calc.setDistanceKeepingPace(distance)
        isCustomDistance = PresetDistance(distance: distance) == nil
    }
}

/// A tappable label/value row. The calculated value is shown in the accent
/// colour so it's always clear which number is the answer.
private struct FieldRow: View {
    var title: String
    var value: String
    var suffix: String? = nil
    var detail: String? = nil
    var isEditing: Bool
    var isCalculated: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.secondary)
                    if isCalculated {
                        Text("calculated")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.title.weight(.semibold).monospacedDigit())
                            .foregroundStyle(isCalculated ? Color.accentColor : Color.primary)
                        if let suffix {
                            Text(suffix).foregroundStyle(.secondary)
                        }
                    }
                    if let detail {
                        Text(detail)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isEditing ? Color.accentColor.opacity(0.15) : nil)
        .accessibilityElement(children: .combine)
        .accessibilityHint(isCalculated ? "Calculated. Double-tap to edit." : "Double-tap to edit.")
    }
}

/// Example values for screenshots: launch a Debug build with `-demo` to
/// open on 400m at 5:45/mi with the pace input showing. Release builds
/// always start from the defaults.
private enum Demo {
    #if DEBUG
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-demo")
    #else
    static let isEnabled = false
    #endif

    static var calculation: Calculation? {
        guard isEnabled else { return nil }
        var calc = Calculation(distance: PresetDistance.m400.distance, time: 0)
        calc.setPace(Pace(secondsPer: .mi, 345))
        return calc
    }

    static var editing: CalculatorField? { isEnabled ? .pace : nil }
}
