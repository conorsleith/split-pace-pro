import PaceCore
import SwiftUI

enum CalculatorMode: String, CaseIterable {
    case distanceTime
    case pace

    var name: String {
        switch self {
        case .distanceTime: "Distance + Time"
        case .pace: "Pace"
        }
    }
}

struct CalculatorView: View {
    @AppStorage("unit") private var unit: DistanceUnit = .mi
    @Environment(\.isWideLayout) private var isWide

    @State private var mode: CalculatorMode = .distanceTime
    @State private var paceInput = Pace(secondsPer: .mi, 360)
    @State private var distance = PresetDistance.k5.distance
    @State private var time: Double = 20 * 60
    @State private var isCustomDistance = false

    private var pace: Pace {
        switch mode {
        case .pace: paceInput
        case .distanceTime: Pace(seconds: time, distance: distance)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isWide {
                    HStack(spacing: 0) {
                        Form { inputSections }
                            .frame(minWidth: 340, idealWidth: 400, maxWidth: 460)
                        Divider()
                        SplitsTable(pace: pace, highlighted: highlightedDistance, onSelect: select)
                    }
                } else {
                    Form {
                        inputSections
                        SplitsTable.Rows(pace: pace, highlighted: highlightedDistance, onSelect: select)
                    }
                    // Keep the answer on screen while spinning the wheels.
                    .safeAreaInset(edge: .top, spacing: 0) {
                        result
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(.bar)
                    }
                }
            }
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

    @ViewBuilder
    private var inputSections: some View {
        Section {
            Picker("Input", selection: $mode) {
                ForEach(CalculatorMode.allCases, id: \.self) { m in
                    Text(m.name).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: mode) { old, new in
                // Carry the current pace across so switching modes never loses it.
                if new == .pace {
                    let carried = Pace(seconds: time, distance: distance)
                    if carried.isValid { paceInput = carried }
                } else if paceInput.isValid {
                    time = paceInput.time(for: distance)
                }
            }
        }

        switch mode {
        case .pace:
            Section("Pace per \(unit.rawValue)") {
                DurationInput(seconds: paceSecondsBinding, showsHours: false)
            }
        case .distanceTime:
            Section("Distance") {
                DistancePicker(distance: $distance, isCustom: $isCustomDistance, unit: unit)
            }
            Section("Time") {
                DurationInput(seconds: $time)
            }
        }

        if isWide {
            Section { result }
        }
    }

    private var result: some View {
        ResultView(pace: pace, unit: unit, showsPrimaryPace: mode == .distanceTime)
    }

    private var paceSecondsBinding: Binding<Double> {
        Binding(
            get: { paceInput.seconds(per: unit) },
            set: { paceInput = Pace(secondsPer: unit, $0) }
        )
    }

    private var highlightedDistance: Distance? {
        mode == .distanceTime ? distance : nil
    }

    /// Tapping a split makes it the input distance, keeping the current pace.
    private func select(_ newDistance: Distance) {
        let current = pace
        guard current.isValid else { return }
        distance = newDistance
        isCustomDistance = PresetDistance(distance: newDistance) == nil
        time = current.time(for: newDistance)
        mode = .distanceTime
    }
}

/// Pace in both units plus treadmill speed.
private struct ResultView: View {
    var pace: Pace
    var unit: DistanceUnit
    var showsPrimaryPace: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsPrimaryPace {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(paceText(unit))
                        .font(.system(size: 44, weight: .semibold).monospacedDigit())
                    Text(unit.paceSuffix).font(.title3).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 16) {
                Text("\(paceText(unit.other)) \(unit.other.paceSuffix)")
                Text(speedText)
            }
            .font(showsPrimaryPace ? .body.monospacedDigit() : .title3.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func paceText(_ unit: DistanceUnit) -> String {
        pace.isValid ? TimeFormat.string(pace.seconds(per: unit)) : "—"
    }

    private var speedText: String {
        guard pace.isValid else { return "— \(unit.speedLabel)" }
        return String(format: "%.1f %@", pace.speed(in: unit), unit.speedLabel)
    }
}
