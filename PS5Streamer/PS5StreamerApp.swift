import SwiftUI

@main
struct PS5StreamerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onDisappear { appState.stop() }
        }
        .windowResizability(.contentSize)
        .commands {
            // Remove File > New Window — single window app
            CommandGroup(replacing: .newItem) {}
        }
    }
}
