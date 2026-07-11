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
        .overlay {
            if let url = appState.viewingImageURL {
                ZStack {
                    Color.black.ignoresSafeArea()
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        case .empty:
                            ProgressView().tint(.white)
                        default:
                            Image(systemName: "photo").font(.largeTitle).foregroundColor(.gray)
                        }
                    }
                }
                .onTapGesture {
                    withAnimation {
                        appState.viewingImageURL = nil
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut, value: appState.viewingImageURL)
    }
}
