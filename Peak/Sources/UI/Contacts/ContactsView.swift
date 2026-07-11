import SwiftUI

// MARK: — Contacts Screen

struct ContactsView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    private var filtered: [User] {
        if searchText.isEmpty { return appState.contacts }
        return appState.contacts.filter {
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
    }
}

#Preview {
    ContactsView()
        .environment(AppState())
}
