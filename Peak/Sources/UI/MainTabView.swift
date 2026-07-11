import SwiftUI

// MARK: — Main Tab Bar

@MainActor
struct MainTabView: View {
    @Environment(AppState.self) private var appState

    @State private var profileImage: Image? = nil

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            Tab(value: AppState.Tab.chats) {
                ChatListView()
            } label: {
                Label("Чаты", systemImage: "bubble.left.and.bubble.right")
            }

            Tab(value: AppState.Tab.contacts) {
                ContactsView()
            } label: {
                Label("Контакты", systemImage: "person.2")
            }

            Tab(value: AppState.Tab.profile) {
                ProfileView()
            } label: {
                if let profileImage {
                    Label { Text("Профиль") } icon: { profileImage }
                } else {
                    Label("Профиль", systemImage: "person.crop.circle")
                }
            }
        }
        .tint(PeakColors.textPrimary)
        .preferredColorScheme(.dark)
        .task(id: appState.currentUser?.avatarUrl) {
            await loadProfileImage(url: appState.currentUser?.avatarUrl)
        }
    }
    
    @MainActor
    private func loadProfileImage(url: String?) async {
        guard let urlString = url, let url = URL(string: urlString) else {
            profileImage = nil
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data)?.circularImage(size: 24)?.withRenderingMode(.alwaysOriginal) {
                profileImage = Image(uiImage: uiImage)
            }
        } catch {
            print("Failed to load tab bar avatar: \(error)")
        }
    }
}

extension UIImage {
    @MainActor
    func circularImage(size: CGFloat) -> UIImage? {
        // First scale the image to fill the target size
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        
        return renderer.image { ctx in
            UIBezierPath(roundedRect: rect, cornerRadius: size / 2).addClip()
            
            // Calculate aspect fill
            let aspectWidth = size / self.size.width
            let aspectHeight = size / self.size.height
            let aspectRatio = max(aspectWidth, aspectHeight)
            
            let scaledImageSize = CGSize(
                width: self.size.width * aspectRatio,
                height: self.size.height * aspectRatio
            )
            
            let x = (size - scaledImageSize.width) / 2.0
            let y = (size - scaledImageSize.height) / 2.0
            
            self.draw(in: CGRect(x: x, y: y, width: scaledImageSize.width, height: scaledImageSize.height))
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
