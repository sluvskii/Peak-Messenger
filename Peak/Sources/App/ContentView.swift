import SwiftUI

// ContentView is a passthrough — root is MainTabView injected from PeakApp
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isUserAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            await appState.checkSession()
        }
    }
}
