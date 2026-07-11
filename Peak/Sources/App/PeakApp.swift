import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebase configuration
        // FirebaseApp.configure() // Uncomment when GoogleService-Info.plist is added
        return true
    }
}

@main
struct PeakApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Injecting global environment objects or color schemes
                .preferredColorScheme(.dark) // Peak is fundamentally a dark/B&W app
        }
    }
}
