import SwiftUI

// MARK: — Chat List Row

struct ChatRowView: View {
    let chat: Chat

    var body: some View {
        HStack(spacing: 14) {

            // Avatar
            AvatarView(user: chat.otherParticipant ?? .alex, size: 56, showOnline: true)

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
                        Text(chat.otherParticipant?.username ?? "Неизвестно")
                            .font(PeakTypography.headline)
                            .foregroundStyle(PeakColors.textPrimary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Time
                    Text(chat.displayTime)
                        .font(PeakTypography.caption)
                        .foregroundStyle(
                            chat.unreadCount > 0
                                ? PeakColors.textPrimary
                                : PeakColors.textTertiary
                        )
                }

                HStack(alignment: .bottom) {
                    // Last message preview
                    HStack(spacing: 4) {
                        // Read receipt for my messages
                        if let last = chat.lastMessage, last.isFromMe {
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
                    if chat.isMuted && chat.unreadCount == 0 {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(PeakColors.textTertiary)
                    } else {
                        UnreadBadge(count: chat.unreadCount)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    ZStack {
        PeakColors.black.ignoresSafeArea()
        VStack(spacing: 0) {
            ForEach(Chat.mockChats) { chat in
                ChatRowView(chat: chat)
                PeakDivider().padding(.leading, 86)
            }
        }
    }
    .preferredColorScheme(.dark)
}
