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

    @State private var isEditingUsername = false
    @State private var newUsername = ""

    // MARK: — Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(user: user, size: 86, showOnline: false)
                        .overlay {
                            if isUploadingAvatar {
                                ProgressView()
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                    
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(PeakColors.accent, .white)
                        .offset(x: 4, y: 4)
                }
            }
            .padding(.top, 20)
            .disabled(isUploadingAvatar)

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
                    newUsername = user.username
                    isEditingUsername = true
                }

                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(PeakTypography.callout)
                        .foregroundStyle(PeakColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.bottom, 20)
        .alert("Изменить имя", isPresented: $isEditingUsername) {
            TextField("Новое имя", text: $newUsername)
            Button("Отмена", role: .cancel) { }
            Button("Сохранить") {
                Task {
                    await saveUsername(newUsername)
                }
            }
        }
    }

    private func saveUsername(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        do {
            try await DatabaseService.shared.updateUsername(trimmed)
            appState.currentUser?.username = trimmed
        } catch {
            print("Failed to update username: \(error)")
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

            SettingsRow(icon: "bell.fill",        title: "Уведомления")
            PeakDivider().padding(.leading, 52)
            SettingsRow(icon: "lock.fill",         title: "Конфиденциальность")
            PeakDivider().padding(.leading, 52)
            SettingsRow(icon: "questionmark.circle.fill", title: "Помощь")
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
