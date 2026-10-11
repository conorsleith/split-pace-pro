import Foundation
import Observation
import PaceCore

/// Owns all tracked races and saves them after every change, so a race in
/// progress survives the app being closed or killed.
@MainActor
@Observable
final class RaceModel {
    var store: RaceStore {
        didSet { save() }
    }

    private let url: URL

    init(url: URL = RaceModel.defaultURL) {
        self.url = url
        if let data = try? Data(contentsOf: url), let store = try? RaceStore.decoded(from: data) {
            self.store = store
        } else {
            self.store = RaceStore()
        }
    }

    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "races.json")
    }

    var selectedRace: TrackedRace? {
        store.selectedIndex.map { store.races[$0] }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try store.encoded().write(to: url, options: .atomic)
        } catch {
            print("Failed to save races: \(error)")
        }
    }
}
