import SwiftUI

@MainActor
struct EditProfileSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var username: String
    @State private var bio: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(user: User) {
        _username = State(initialValue: user.username)
        _bio = State(initialValue: user.bio)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PeakColors.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    if let error = errorMessage {
                        Text(error)
                            .font(PeakTypography.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Username Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Имя пользователя")
                                .font(PeakTypography.tiny)
                                .foregroundStyle(PeakColors.textSecondary)
                                .kerning(1.0)
                            
                            TextField("Имя", text: $username)
                                .font(PeakTypography.body)
                                .foregroundStyle(PeakColors.textPrimary)
                                .padding()
                                .background(PeakColors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(PeakColors.divider, lineWidth: 0.5)
                                )
                        }
                        
                        // Bio Field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("О себе")
                                    .font(PeakTypography.tiny)
                                    .foregroundStyle(PeakColors.textSecondary)
                                    .kerning(1.0)
                                Spacer()
                                Text("\(bio.count)/70")
                                    .font(PeakTypography.tiny)
                                    .foregroundStyle(PeakColors.textTertiary)
                            }
                            
                            TextField("Расскажите о себе", text: $bio, axis: .vertical)
                                .font(PeakTypography.body)
                                .foregroundStyle(PeakColors.textPrimary)
                                .lineLimit(3...5)
                                .padding()
                                .background(PeakColors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(PeakColors.divider, lineWidth: 0.5)
                                )
                                .onChange(of: bio) { _, newValue in
                                    if newValue.count > 70 {
                                        bio = String(newValue.prefix(70))
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Save Button
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(PeakColors.black)
                            } else {
                                Text("Сохранить изменения")
                                    .font(PeakTypography.button)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? PeakColors.textSecondary : PeakColors.textPrimary)
                        .foregroundStyle(PeakColors.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Редактировать профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundStyle(PeakColors.textSecondary)
                }
            }
        }
    }
    
    private func saveProfile() async {
        let trimmedName = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Update DB username
            if trimmedName != appState.currentUser?.username {
                try await DatabaseService.shared.updateUsername(trimmedName)
                appState.currentUser?.username = trimmedName
            }
            
            // Update DB bio
            if trimmedBio != appState.currentUser?.bio {
                try await DatabaseService.shared.updateBio(trimmedBio)
                appState.currentUser?.bio = trimmedBio
            }
            
            // Success
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
        } catch {
            print("Failed to save profile: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
