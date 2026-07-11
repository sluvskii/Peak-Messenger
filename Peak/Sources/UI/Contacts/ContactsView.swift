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
            ZStack(alignment: .top) {
                PeakColors.black.ignoresSafeArea()

                ScrollView {
                    // Padding to push content below the floating header
                    Spacer().frame(height: 120)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { user in
                            contactRow(user)
                            PeakDivider().padding(.leading, 70)
                        }
                    }
                    .padding(.bottom, 100) // Padding for tab bar
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea()
                
                // Floating Header
                floatingHeader
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: — Floating Header
    
    private var floatingHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Contacts")
                    .font(PeakTypography.display)
                    .foregroundStyle(PeakColors.textPrimary)
                Spacer()
                
                Button {
                    // Add contact action
                } label: {
                    Image(systemName: "person.badge.plus")
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
                TextField("Search contacts", text: $searchText)
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

    @ViewBuilder
    private func contactRow(_ user: User) -> some View {
        HStack(spacing: 14) {
            AvatarView(user: user, size: 46, showOnline: true)

            VStack(alignment: .leading, spacing: 3) {
                Text(user.username)
                    .font(PeakTypography.headline)
                    .foregroundStyle(PeakColors.textPrimary)

                Text(user.isOnline ? "online" : user.lastSeenText)
                    .font(PeakTypography.callout)
                    .foregroundStyle(PeakColors.textSecondary)
            }

            Spacer()

            // Message shortcut
            Button {
                // navigate to chat
            } label: {
                Image(systemName: "bubble.right")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(PeakColors.textTertiary)
                    .padding(10)
                    .background(PeakColors.surface)
                    .clipShape(Circle())
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
