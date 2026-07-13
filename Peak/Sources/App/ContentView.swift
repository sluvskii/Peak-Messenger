import SwiftUI

// ContentView is a passthrough — root is MainTabView injected from PeakApp
@MainActor
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
                FullscreenMediaView(url: url, isPresented: Binding(
                    get: { appState.viewingImageURL != nil },
                    set: { show in if !show { appState.viewingImageURL = nil } }
                ))
                .zIndex(100)
            }
        }
        .animation(.easeInOut, value: appState.viewingImageURL)
    }
}

@MainActor
struct FullscreenMediaView: View {
    let url: URL
    @Binding var isPresented: Bool
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .opacity(max(0.3, 1.0 - (Double(abs(dragOffset.height)) / 600.0)))
                .ignoresSafeArea()
            
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .offset(dragOffset)
                        .scaleEffect(max(0.65, 1.0 - (Double(abs(dragOffset.height)) / 1200.0)))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    if abs(value.translation.height) > 100 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            isPresented = false
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                            dragOffset = .zero
                                        }
                                    }
                                }
                        )
                case .empty:
                    ProgressView().tint(.white)
                default:
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }
            }
            
            // Top Controls
            HStack(spacing: 16) {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color(white: 0.15))
                        .clipShape(Circle())
                }
                
                Button {
                    withAnimation {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color(white: 0.15))
                        .clipShape(Circle())
                }
            }
            .padding(.top, 60)
            .padding(.trailing, 20)
        }
        .transition(.opacity)
        .onDisappear {
            dragOffset = .zero
        }
    }
}
