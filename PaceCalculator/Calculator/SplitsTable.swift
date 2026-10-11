import PaceCore
import SwiftUI

/// Time at the current pace for every preset distance (and a custom input
/// distance, if any). Tapping a row selects that distance.
struct SplitsTable: View {
    var pace: Pace
    var highlighted: Distance?
    var onSelect: (Distance) -> Void

    var body: some View {
        List {
            Rows(pace: pace, highlighted: highlighted, onSelect: onSelect)
        }
    }

    struct Rows: View {
        var pace: Pace
        var highlighted: Distance?
        var onSelect: (Distance) -> Void

        var body: some View {
            Section("Splits") {
                ForEach(rows, id: \.meters) { row in
                    Button {
                        onSelect(row.distance)
                    } label: {
                        HStack {
                            Text(row.name)
                            Spacer()
                            Text(pace.isValid ? TimeFormat.string(pace.time(for: row.distance)) : "—")
                                .monospacedDigit()
                        }
                        .fontWeight(row.isHighlighted ? .semibold : .regular)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(row.isHighlighted ? Color.accentColor.opacity(0.15) : nil)
                }
            }
        }

        private struct Row {
            var name: String
            var distance: Distance
            var isHighlighted: Bool
            var meters: Double { distance.meters }
        }

        private var rows: [Row] {
            var rows = PresetDistance.allCases.map {
                Row(name: $0.name, distance: $0.distance, isHighlighted: isHighlighted($0.distance))
            }
            if let highlighted, highlighted.meters > 0, PresetDistance(distance: highlighted) == nil {
                let name = String(format: "%.2f km · %.2f mi", highlighted.value(in: .km), highlighted.value(in: .mi))
                rows.append(Row(name: name, distance: highlighted, isHighlighted: true))
                rows.sort { $0.meters < $1.meters }
            }
            return rows
        }

        private func isHighlighted(_ d: Distance) -> Bool {
            guard let highlighted else { return false }
            return abs(highlighted.meters - d.meters) < 0.001
        }
    }
}
