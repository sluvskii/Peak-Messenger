import SwiftUI

@main
struct PeakApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if appState.isUserAuthenticated {
                Task {
                    if newPhase == .active {
                        try? await DatabaseService.shared.updatePresence(isOnline: true)
                    } else if newPhase == .background {
                        try? await DatabaseService.shared.updatePresence(isOnline: false)
                    }
                }
            }
        }
    }
}
