import SwiftUI

@main
struct PeakApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
    }
}
