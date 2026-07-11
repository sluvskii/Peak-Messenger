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
            ($0.otherParticipant?.username.localizedCaseInsensitiveContains(searchText) ?? false)
            || ($0.lastMessage?.displayText.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                PeakColors.black.ignoresSafeArea()

                if appState.chats.isEmpty {
                    emptyState
                } else {
                    chatList
                }
                
                // Floating Header
                floatingHeader
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: — Subviews

    private var chatList: some View {
        ScrollView {
            // Padding to push content below the floating header
            Spacer().frame(height: 120)
            
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
            .padding(.bottom, 100) // Padding for tab bar
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
        .navigationDestination(for: Chat.self) { chat in
            ChatDetailView(chat: chat)
        }
    }

    private var floatingHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Peak")
                    .font(PeakTypography.display)
                    .foregroundStyle(PeakColors.textPrimary)
                
                Spacer()
                
                Button {
                    // New chat action
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(PeakColors.textPrimary)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            
            // Floating Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PeakColors.textSecondary)
                TextField("Search conversations", text: $searchText)
                    .font(PeakTypography.body)
                    .foregroundStyle(PeakColors.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 16)
        }
        .padding(.top, 50)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [PeakColors.black, PeakColors.black.opacity(0.8), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(PeakColors.textTertiary)
            Text("No conversations yet")
                .font(PeakTypography.headline)
                .foregroundStyle(PeakColors.textSecondary)
            Spacer()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ChatListView()
        .environment(AppState())
}
