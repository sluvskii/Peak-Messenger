import SwiftUI

// MARK: — Contacts Screen

struct ContactsView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var users: [User] = []
    @State private var selectedChat: Chat?
    @State private var isLoading = false

    private var filtered: [User] {
        let contacts = users
        if searchText.isEmpty { return contacts }
        return contacts.filter {
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PeakColors.black.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { user in
                            contactRow(user)
                            PeakDivider().padding(.leading, 70)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Контакты")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Поиск")
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedChat) { chat in
                ChatDetailView(chat: chat)
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .task {
                do {
                    users = try await DatabaseService.shared.fetchAllUsers()
                } catch {
                    print("Failed to load users: \(error)")
                }
            }
        }
    }

    @ViewBuilder
    private func contactRow(_ user: User) -> some View {
        HStack(spacing: 14) {
            AvatarView(user: user, size: 46, showOnline: true)

            VStack(alignment: .leading, spacing: 3) {
                Text(user.username)
                    .font(PeakTypography.headline)
                    .foregroundStyle(PeakColors.textPrimary)

                Text(user.isOnline ? "в сети" : user.lastSeenText)
                    .font(PeakTypography.callout)
                    .foregroundStyle(PeakColors.textSecondary)
            }

            Spacer()

            // Message shortcut
            Button {
                // navigate to chat
            } label: {
                Image(systemName: "bubble.right")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(PeakColors.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            openChat(with: user)
        }
    }
    
    private func openChat(with user: User) {
        // Fast path: Check if we already have this chat in AppState
        if let existingChat = appState.chats.first(where: { chat in
            if user.id == appState.currentUser?.id {
                return chat.participants.count == 1 && chat.participants.first?.id == user.id
            } else {
                return chat.participants.count == 2 && chat.participants.contains(where: { $0.id == user.id })
            }
        }) {
            selectedChat = existingChat
            return
        }
        
        // Slow path: Ask database to get or create
        isLoading = true
        Task {
            do {
                let chat = try await DatabaseService.shared.getOrCreateChat(with: user.id)
                await MainActor.run {
                    isLoading = false
                    selectedChat = chat
                    if !appState.chats.contains(where: { $0.id == chat.id }) {
                        appState.chats.append(chat)
                    }
                }
            } catch {
                print("Failed to open chat: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

#Preview {
    ContactsView()
        .environment(AppState())
}
