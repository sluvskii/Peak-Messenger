import SwiftUI

// MARK: — Chat List Screen

struct ChatListView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    private var filteredChats: [Chat] {
        let sorted = appState.chats.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return ($0.lastMessage?.timestamp ?? .distantPast) > ($1.lastMessage?.timestamp ?? .distantPast)
        }
        if searchText.isEmpty { return sorted }
        return sorted.filter {
            ($0.otherParticipant(myId: appState.currentUser?.id)?.username.localizedCaseInsensitiveContains(searchText) ?? false)
            || ($0.lastMessage?.displayText.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PeakColors.black.ignoresSafeArea()

                if appState.chats.isEmpty {
                    emptyState
                } else {
                    chatList
                }
            }
            .navigationTitle("Peak")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Поиск")
            .toolbar { toolbarContent }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    // MARK: — Subviews

    private var chatList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredChats) { chat in
                    NavigationLink(value: chat) {
                        ChatRowView(chat: chat)
                    }
                    .buttonStyle(PressButtonStyle())

                    PeakDivider()
                        .padding(.leading, 86)
                }
            }
            .navigationDestination(for: Chat.self) { chat in
                ChatDetailView(chat: chat)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(PeakColors.textTertiary)
            Text("Пока нет чатов")
                .font(PeakTypography.headline)
                .foregroundStyle(PeakColors.textSecondary)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                appState.selectedTab = .contacts
            } label: {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(PeakColors.textPrimary)
            }
        }
    }
}

#Preview {
    ChatListView()
        .environment(AppState())
}
