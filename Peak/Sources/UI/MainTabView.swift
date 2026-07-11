import SwiftUI

// MARK: — Main Tab Bar

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            Tab(value: AppState.Tab.chats) {
                ChatListView()
            } label: {
                Label("Chats", systemImage: "bubble.left.and.bubble.right")
            }

            Tab(value: AppState.Tab.contacts) {
                ContactsView()
            } label: {
                Label("Contacts", systemImage: "person.2")
            }

            Tab(value: AppState.Tab.profile) {
                ProfileView()
            } label: {
                Label("Profile", systemImage: "person.circle")
            }
        }
        .tint(PeakColors.textPrimary)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
