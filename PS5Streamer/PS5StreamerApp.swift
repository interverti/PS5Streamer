import SwiftUI

@main
struct PS5StreamerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(appState)
        } label: {
            // Icon reflects running state
            Image(systemName: appState.isRunning
                  ? "dot.radiowaves.left.and.right"
                  : "dot.radiowaves.left.and.right")
            .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
    }
}
