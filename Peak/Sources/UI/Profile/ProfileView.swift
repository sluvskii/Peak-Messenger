import SwiftUI
import PhotosUI

// MARK: — Profile Screen

@MainActor
struct ProfileView: View {
    @Environment(AppState.self) private var appState

    var user: User { appState.currentUser ?? .me }
    
    @State private var isUploadingAvatar = false
    @State private var selectedItem: PhotosPickerItem? = nil
    
    @State private var showUploadError = false
    @State private var uploadError = ""

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
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    await handleAvatarSelection(newItem)
                }
            }
            .alert("Ошибка загрузки", isPresented: $showUploadError) {
                Button("Ок", role: .cancel) { }
            } message: {
                Text(uploadError)
            }
        }
    }

    @State private var isShowingEditSheet = false
    
    // Interactive settings values persisted in AppStorage
    @AppStorage("settings_notifications") private var notificationsEnabled = true
    @AppStorage("settings_privacy") private var privacyLockEnabled = false
    @AppStorage("settings_read_receipts") private var readReceiptsEnabled = true

    // MARK: — Header

    private var headerSection: some View {
        let currentUser = user
        let uploading = isUploadingAvatar
        return VStack(spacing: 14) {
            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(user: currentUser, size: 86, showOnline: false)
                        .overlay {
                            if uploading {
                                ProgressView()
                                    .padding()
                                    .glassBackgroundEffect(in: Circle())
                            }
                        }
                    
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(PeakColors.accent, .white)
                        .offset(x: 4, y: 4)
                }
            }
            .padding(.top, 20)
            .disabled(uploading)

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.username)
                        .font(PeakTypography.display)
                        .foregroundStyle(PeakColors.textPrimary)
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PeakColors.textTertiary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isShowingEditSheet = true
                }

                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(PeakTypography.callout)
                        .foregroundStyle(PeakColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isShowingEditSheet = true
                        }
                } else {
                    Button("Добавить описание") {
                        isShowingEditSheet = true
                    }
                    .font(PeakTypography.callout)
                    .foregroundStyle(PeakColors.accent)
                }
            }
        }
        .padding(.bottom, 20)
        .sheet(isPresented: $isShowingEditSheet) {
            EditProfileSheet(user: user)
                .environment(appState)
        }
    }

    // MARK: — Avatar Handling
    
    private func handleAvatarSelection(_ item: PhotosPickerItem?) async {
        guard let item = item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let userId = appState.currentUser?.id else { return }
        
        isUploadingAvatar = true
        do {
            let path = "\(userId)/avatar_\(Date().timeIntervalSince1970).jpg"
            let url = try await StorageService.shared.uploadMedia(data, bucket: "avatars", path: path, contentType: "image/jpeg")
            
            // Update database
            try await DatabaseService.shared.updateAvatarUrl(url.absoluteString)
            
            // Update local state
            appState.currentUser?.avatarUrl = url.absoluteString
        } catch {
            print("Failed to upload avatar: \(error)")
            uploadError = error.localizedDescription
            showUploadError = true
        }
        isUploadingAvatar = false
        selectedItem = nil
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

            SettingsToggleRow(icon: "bell.fill", title: "Уведомления", isOn: $notificationsEnabled)
            PeakDivider().padding(.leading, 52)
            SettingsToggleRow(icon: "lock.fill", title: "Защита приложения", isOn: $privacyLockEnabled)
            PeakDivider().padding(.leading, 52)
            SettingsToggleRow(icon: "eye.fill", title: "Отчеты о прочтении", isOn: $readReceiptsEnabled)
            PeakDivider().padding(.leading, 52)
            
            Button {
                Task {
                    do {
                        try await AuthenticationService.shared.signOut()
                    } catch {
                        print("Error signing out: \(error)")
                    }
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .frame(width: 22)
                        .foregroundStyle(.red)
                    Text("Выйти")
                        .font(PeakTypography.body)
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
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

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(PeakColors.textSecondary)
            Text(title)
                .font(PeakTypography.body)
                .foregroundStyle(PeakColors.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(PeakColors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
