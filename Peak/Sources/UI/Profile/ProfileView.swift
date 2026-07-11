import SwiftUI

// MARK: — Profile Screen

struct ProfileView: View {
    @Environment(AppState.self) private var appState

    var user: User { appState.currentUser }

    var body: some View {
        NavigationStack {
            ZStack {
                PeakColors.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Avatar + Name Header
                        headerSection

                        VStack(spacing: 0) {
                            infoSection
                            settingsSection
                        }
                        .padding(.top, 24)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    // MARK: — Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            AvatarView(user: user, size: 86, showOnline: false)
                .padding(.top, 20)

            VStack(spacing: 4) {
                Text(user.username)
                    .font(PeakTypography.display)
                    .foregroundStyle(PeakColors.textPrimary)

                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(PeakTypography.callout)
                        .foregroundStyle(PeakColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: — Info

    private var infoSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Информация")

            if let phone = user.phone {
                InfoRow(icon: "phone.fill", label: "Телефон", value: phone)
                PeakDivider().padding(.leading, 52)
            }

            InfoRow(icon: "bubble.left.fill", label: "О себе", value: user.bio.isEmpty ? "—" : user.bio)
        }
        .background(PeakColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: — Settings

    private var settingsSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Настройки")

            SettingsRow(icon: "bell.fill",        title: "Уведомления")
            PeakDivider().padding(.leading, 52)
            SettingsRow(icon: "lock.fill",         title: "Конфиденциальность")
            PeakDivider().padding(.leading, 52)
            SettingsRow(icon: "questionmark.circle.fill", title: "Помощь")
        }
        .background(PeakColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }
}

// MARK: — Sub-components

struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(PeakTypography.tiny)
                .foregroundStyle(PeakColors.textTertiary)
                .kerning(1.2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(PeakColors.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(PeakTypography.caption)
                    .foregroundStyle(PeakColors.textTertiary)
                Text(value)
                    .font(PeakTypography.body)
                    .foregroundStyle(PeakColors.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        Button {
            // navigate
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundStyle(PeakColors.textSecondary)
                Text(title)
                    .font(PeakTypography.body)
                    .foregroundStyle(PeakColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PeakColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
