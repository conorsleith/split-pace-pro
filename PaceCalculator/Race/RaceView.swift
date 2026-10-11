import PaceCore
import SwiftUI

struct RaceView: View {
    @Environment(RaceModel.self) private var model
    @AppStorage("unit") private var unit: DistanceUnit = .mi
    @State private var isAddingRace = false
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if model.store.races.count > 1 {
                    racePicker
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                if let race = model.selectedRace {
                    RaceDetailView(race: raceBinding(race.id), unit: unit)
                        .id(race.id)
                } else {
                    ContentUnavailableView {
                        Label("No races", systemImage: "flag.checkered")
                    } description: {
                        Text("Add a race to follow it split by split.")
                    } actions: {
                        Button("Add race") { isAddingRace = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle(model.selectedRace?.title ?? "Race")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add race", systemImage: "plus") { isAddingRace = true }
                        if model.selectedRace != nil {
                            Button("Delete this race", systemImage: "trash", role: .destructive) {
                                isConfirmingDelete = true
                            }
                        }
                    } label: {
                        Label("Races", systemImage: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    UnitToggle(unit: $unit)
                }
            }
            .confirmationDialog(
                "Delete \(model.selectedRace?.title ?? "race")?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let id = model.selectedRace?.id { model.store.remove(id: id) }
                }
            } message: {
                Text("Its recorded splits will be lost.")
            }
            .sheet(isPresented: $isAddingRace) {
                AddRaceSheet(unit: unit) { model.store.add($0) }
            }
        }
    }

    @ViewBuilder
    private var racePicker: some View {
        @Bindable var model = model
        let selection = Binding(
            get: { model.store.selectedID ?? model.store.races.first?.id },
            set: { model.store.selectedID = $0 }
        )
        if model.store.races.count <= 3 {
            Picker("Race", selection: selection) {
                ForEach(model.store.races) { race in
                    Text(shortTitle(race)).tag(Optional(race.id))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } else {
            Picker("Race", selection: selection) {
                ForEach(model.store.races) { race in
                    Text(race.title).tag(Optional(race.id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// When all races share a kind (e.g. men's and women's marathon) the
    /// label alone is enough to tell them apart.
    private func shortTitle(_ race: TrackedRace) -> String {
        let races = model.store.races
        let sameKind = Set(races.map(\.kind)).count == 1
        if sameKind, race.customName?.isEmpty ?? true, race.label != .none {
            return race.label.name
        }
        return race.title
    }

    private func raceBinding(_ id: UUID) -> Binding<TrackedRace> {
        let fallback = model.selectedRace!
        return Binding(
            get: { model.store.races.first { $0.id == id } ?? fallback },
            set: { race in
                if let i = model.store.races.firstIndex(where: { $0.id == id }) {
                    model.store.races[i] = race
                }
            }
        )
    }
}
