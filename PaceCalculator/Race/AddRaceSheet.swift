import PaceCore
import SwiftUI

struct AddRaceSheet: View {
    var unit: DistanceUnit
    var onAdd: (TrackedRace) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: RaceKind = .marathon
    @State private var splitType: SplitType = .km5
    @State private var label: RaceLabel = .none
    @State private var name = ""

    private let grid = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        NavigationStack {
            Form {
                Section("Track") { kindGrid(RaceKind.allCases.filter(\.isTrack)) }
                Section("Road") { kindGrid(RaceKind.allCases.filter { !$0.isTrack }) }

                if kind.splitTypes.count > 1 {
                    Section("Splits") {
                        Picker("Splits", selection: $splitType) {
                            ForEach(kind.splitTypes) { Text($0.name).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                Section("Label") {
                    LazyVGrid(columns: grid, spacing: 8) {
                        ForEach(RaceLabel.allCases) { l in
                            Chip(title: l.name, isSelected: label == l) { label = l }
                        }
                    }
                    TextField("Custom name (optional)", text: $name)
                }
            }
            .navigationTitle("Add race")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        onAdd(TrackedRace(
                            kind: kind,
                            splitType: splitType,
                            label: label,
                            customName: trimmed.isEmpty ? nil : trimmed
                        ))
                        dismiss()
                    }
                }
            }
            .onChange(of: kind, initial: true) { _, new in
                if !new.splitTypes.contains(splitType) { splitType = new.defaultSplitType }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }

    private func kindGrid(_ kinds: [RaceKind]) -> some View {
        LazyVGrid(columns: grid, spacing: 8) {
            ForEach(kinds) { k in
                Chip(title: k.name, isSelected: kind == k) { kind = k }
            }
        }
        .padding(.vertical, 4)
    }
}
