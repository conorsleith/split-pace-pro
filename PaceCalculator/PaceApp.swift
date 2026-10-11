import SwiftUI

@main
struct PaceApp: App {
    @State private var raceModel = RaceModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(raceModel)
                .formStyle(.grouped)
                #if os(iOS)
                .listSectionSpacing(.compact)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 900, height: 700)
        #endif
    }
}

private enum AppTab: String {
    case calculator, race
}

private struct RootView: View {
    /// Reopen on the last tab, so a race in progress comes straight back.
    @AppStorage("tab") private var tab: AppTab = .calculator

    var body: some View {
        TabView(selection: $tab) {
            CalculatorView()
                .tabItem { Label("Calculator", systemImage: "stopwatch") }
                .tag(AppTab.calculator)
            RaceView()
                .tabItem { Label("Race", systemImage: "flag.checkered") }
                .tag(AppTab.race)
        }
    }
}
