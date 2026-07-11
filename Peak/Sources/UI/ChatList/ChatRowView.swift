import SwiftUI

// MARK: — Chat List Row

@MainActor
struct ChatRowView: View {
    let chat: Chat

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 14) {

            // Avatar
            AvatarView(user: chat.otherParticipant(myId: appState.currentUser?.id) ?? .alex, size: 56, showOnline: true)

            // Content
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    // Name
                    HStack(spacing: 5) {
                        if chat.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(PeakColors.textTertiary)
                        }
                        Text(chat.otherParticipant(myId: appState.currentUser?.id)?.username ?? "Неизвестно")
                            .font(PeakTypography.headline)
                            .foregroundStyle(PeakColors.textPrimary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Time
                    Text(chat.displayTime)
                        .font(PeakTypography.caption)
                        .foregroundStyle(
                            chat.unreadCount(myId: appState.currentUser?.id) > 0
                                ? PeakColors.textPrimary
                                : PeakColors.textTertiary
                        )
                }

                HStack(alignment: .bottom) {
                    // Last message preview
                    HStack(spacing: 4) {
                        // Read receipt for my messages
                        if let last = chat.lastMessage, last.isFromMe(myId: appState.currentUser?.id) {
                            Image(systemName: last.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PeakColors.textTertiary)
                        }

                        Text(chat.lastMessage?.displayText ?? "")
                            .font(PeakTypography.callout)
                            .foregroundStyle(PeakColors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Unread badge or mute icon
                    if chat.isMuted && chat.unreadCount(myId: appState.currentUser?.id) == 0 {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(PeakColors.textTertiary)
                    } else {
                        UnreadBadge(count: chat.unreadCount(myId: appState.currentUser?.id))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                appState.togglePin(chatId: chat.id)
            } label: {
                Label(chat.isPinned ? "Открепить" : "Закрепить", systemImage: chat.isPinned ? "pin.slash" : "pin")
            }
            
            Button {
                appState.toggleMute(chatId: chat.id)
            } label: {
                Label(chat.isMuted ? "Включить звук" : "Выключить звук", systemImage: chat.isMuted ? "bell" : "bell.slash")
            }
            
            Button(role: .destructive) {
                appState.deleteChat(chatId: chat.id)
            } label: {
                Label("Удалить чат", systemImage: "trash")
            }
        }
    }
}

#Preview {
    ZStack {
        PeakColors.black.ignoresSafeArea()
        VStack(spacing: 0) {
            ForEach(Chat.mockChats) { chat in
                ChatRowView(chat: chat)
                    .environment(AppState())
                PeakDivider().padding(.leading, 86)
            }
        }
    }
    .preferredColorScheme(.dark)
}
