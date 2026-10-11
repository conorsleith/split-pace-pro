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
    @Environment(\.isWideLayout) private var isWide

    @State private var calc = Calculation(distance: PresetDistance.k5.distance, time: 20 * 60)
    @State private var editing: CalculatorField?
    @State private var isCustomDistance = false

    var body: some View {
        NavigationStack {
            Group {
                if isWide {
                    HStack(spacing: 0) {
                        Form {
                            fieldRows
                            if let editing {
                                Section(editing.title) { editor(for: editing) }
                            }
                        }
                        .frame(minWidth: 340, idealWidth: 400, maxWidth: 460)
                        Divider()
                        SplitsTable(pace: calc.pace, highlighted: calc.distance, onSelect: selectSplit)
                    }
                } else {
                    Form {
                        fieldRows
                        SplitsTable.Rows(pace: calc.pace, highlighted: calc.distance, onSelect: selectSplit)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if let editing {
                            EditorPanel(title: editing.title, onDone: { self.editing = nil }) {
                                editor(for: editing)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
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

    private func toggle(_ field: CalculatorField) {
        editing = editing == field ? nil : field
    }

    private var distanceText: String {
        if let preset = PresetDistance(distance: calc.distance) {
            return preset.name
        }
        return String(format: "%.2f %@", calc.distance.value(in: unit), unit.rawValue)
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
            DistancePicker(distance: $calc.distance, isCustom: $isCustomDistance, unit: unit)
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

/// Bottom panel that holds the input for the row being edited, in the
/// place a keyboard would appear.
private struct EditorPanel<Content: View>: View {
    var title: String
    var onDone: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button("Done", action: onDone).fontWeight(.semibold)
            }
            content
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 8, y: -2)
    }
}
