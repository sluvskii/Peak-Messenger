import SwiftUI

@MainActor
struct ChatInfoView: View {
    let chat: Chat
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    private var participant: User {
        chat.otherParticipant(myId: appState.currentUser?.id) ?? .alex
    }
    
    @State private var isShowingDeleteConfirmation = false
    
    var body: some View {
        ZStack {
            PeakColors.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section (Avatar + Username)
                    VStack(spacing: 12) {
                        AvatarView(user: participant, size: 100, showOnline: true)
                        
                        VStack(spacing: 4) {
                            Text(participant.username)
                                .font(PeakTypography.display)
                                .foregroundStyle(PeakColors.textPrimary)
                            
                            Text(participant.isOnline ? "в сети" : participant.lastSeenText)
                                .font(PeakTypography.callout)
                                .foregroundStyle(PeakColors.textSecondary)
                        }
                    }
                    .padding(.top, 24)
                    
                    // Info Section
                    VStack(spacing: 0) {
                        SectionHeader(title: "Информация")
                        
                        if let phone = participant.phone, !phone.isEmpty {
                            InfoRow(icon: "phone.fill", label: "Телефон", value: phone)
                                .onLongPressGesture {
                                    UIPasteboard.general.string = phone
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            PeakDivider().padding(.leading, 52)
                        }
                        
                        InfoRow(icon: "bubble.left.fill", label: "О себе", value: participant.bio.isEmpty ? "—" : participant.bio)
                            .onLongPressGesture {
                                if !participant.bio.isEmpty {
                                    UIPasteboard.general.string = participant.bio
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                    }
                    .background(PeakColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    
                    // Actions Section
                    VStack(spacing: 0) {
                        SectionHeader(title: "Настройки чата")
                        
                        // Mute toggle
                        HStack(spacing: 14) {
                            Image(systemName: (appState.chat(for: chat.id)?.isMuted == true) ? "bell.slash.fill" : "bell.fill")
                                .frame(width: 22)
                                .foregroundStyle(PeakColors.textSecondary)
                            Text("Без звука")
                                .font(PeakTypography.body)
                                .foregroundStyle(PeakColors.textPrimary)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appState.chat(for: chat.id)?.isMuted ?? false },
                                set: { _ in appState.toggleMute(chatId: chat.id) }
                            ))
                            .labelsHidden()
                            .tint(PeakColors.textPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        
                        PeakDivider().padding(.leading, 52)
                        
                        // Delete chat button
                        Button {
                            isShowingDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "trash.fill")
                                    .frame(width: 22)
                                    .foregroundStyle(.red)
                                Text("Удалить чат")
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
                }
            }
        }
        .navigationTitle("Информация")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Вы уверены, что хотите удалить чат? Это действие удалит чат и всю историю сообщений для вас.",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить чат", role: .destructive) {
                appState.deleteChat(chatId: chat.id)
                // Go back to the chat list by dismissing this and navigation stack pop
                dismiss()
                // Set Tab to chats
                appState.selectedTab = .chats
            }
            Button("Отмена", role: .cancel) {}
        }
    }
}
