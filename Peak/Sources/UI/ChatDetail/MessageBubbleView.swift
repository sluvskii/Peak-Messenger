import SwiftUI

// MARK: — Message Bubble

@MainActor
struct MessageBubbleView: View {
    @Environment(AppState.self) private var appState
    let message: Message

    private var isFromMe: Bool { message.isFromMe(myId: appState.currentUser?.id) }
    
    private var repliedMessage: Message? {
        if let replyToId = message.replyToId {
            return appState.chat(for: message.chatId)?.messages.first(where: { $0.id == replyToId })
        }
        return nil
    }
    
    private var repliedUser: User? {
        guard let replied = repliedMessage else { return nil }
        return appState.chat(for: message.chatId)?.participants.first { $0.id == replied.senderId }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                ZStack(alignment: isFromMe ? .bottomTrailing : .bottomLeading) {
                    bubbleBody
                        .onTapGesture(count: 2) {
                            if let myId = appState.currentUser?.id {
                                appState.addReaction("❤️", to: message.id, senderId: myId)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        }
                    
                    if let msgReactions = appState.reactions[message.id], !msgReactions.isEmpty {
                        reactionsOverlay(msgReactions)
                    }
                }
                .padding(.bottom, appState.reactions[message.id]?.isEmpty == false ? 8 : 0)
                
                metaRow
            }

            if !isFromMe { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    // MARK: — Bubble Body

    @ViewBuilder
    private var bubbleBody: some View {
        switch message.type {
        case .text, .deleted:
            VStack(alignment: .leading, spacing: 4) {
                if let replied = repliedMessage {
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(isFromMe ? PeakColors.black : PeakColors.accent)
                            .frame(width: 2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(repliedUser?.username ?? "Ответ")
                                .font(PeakTypography.tiny)
                                .bold()
                                .foregroundStyle(isFromMe ? PeakColors.black : PeakColors.accent)
                            Text(replied.displayText)
                                .font(PeakTypography.caption)
                                .foregroundStyle(isFromMe ? PeakColors.black.opacity(0.6) : PeakColors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.bottom, 2)
                }
                Text(message.displayText)
                    .font(PeakTypography.body)
                    .foregroundStyle(isFromMe ? PeakColors.black : PeakColors.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isFromMe ? PeakColors.bubbleOut : PeakColors.bubbleIn)
            .clipShape(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PeakColors.divider, lineWidth: isFromMe ? 0 : 0.5)
            )

        case .image:
            if let mediaUrlString = message.mediaUrl, let url = URL(string: mediaUrlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 200, height: 200)
                            .background(PeakColors.surface)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 240, maxHeight: 300)
                    case .failure:
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(PeakColors.textSecondary)
                            .frame(width: 200, height: 200)
                            .background(PeakColors.surface)
                    @unknown default:
                        EmptyView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onTapGesture {
                    appState.viewingImageURL = url
                }
            } else {
                Text("Image missing")
                    .font(PeakTypography.callout)
                    .foregroundStyle(PeakColors.textSecondary)
                    .padding()
            }

        case .voice:
            voiceBubblePlayerView

        case .video, .circle, .file:
            HStack(spacing: 10) {
                Image(systemName: mediaIcon)
                    .font(.system(size: 22, weight: .light))
                Text(message.displayText)
                    .font(PeakTypography.callout)
            }
            .foregroundStyle(isFromMe ? PeakColors.black : PeakColors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isFromMe ? PeakColors.bubbleOut : PeakColors.bubbleIn)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: — Meta (time + read status)

    private var metaRow: some View {
        HStack(spacing: 4) {
            Text(formatTime(message.timestamp))
                .font(PeakTypography.tiny)
                .foregroundStyle(PeakColors.textTertiary)

            if isFromMe {
                Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PeakColors.textTertiary)
            }

            if message.isEdited {
                Text("изм.")
                    .font(PeakTypography.tiny)
                    .foregroundStyle(PeakColors.textTertiary)
            }
        }
    }

    // MARK: — Helpers

    private var isPlayingThis: Bool {
        VoiceMessageManager.shared.playingMessageId == message.id && VoiceMessageManager.shared.isPlaying
    }
    
    private var playProgress: Double {
        if VoiceMessageManager.shared.playingMessageId == message.id {
            return VoiceMessageManager.shared.playProgress
        }
        return 0.0
    }
    
    private var durationText: String {
        if VoiceMessageManager.shared.playingMessageId == message.id {
            return formatTimeSeconds(VoiceMessageManager.shared.playCurrentTime)
        }
        return formatTimeSeconds(message.duration ?? 0)
    }

    private var voiceBubblePlayerView: some View {
        HStack(spacing: 12) {
            Button {
                if let mediaUrlString = message.mediaUrl, let url = URL(string: mediaUrlString) {
                    VoiceMessageManager.shared.playVoiceMessage(url: url, messageId: message.id)
                }
            } label: {
                Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(isFromMe ? PeakColors.black : PeakColors.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(isFromMe ? PeakColors.black.opacity(0.1) : PeakColors.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                // Waveform rendering
                HStack(spacing: 2) {
                    ForEach(0..<18, id: \.self) { bar in
                        let hash = abs((message.id.uuidString + String(bar)).hashValue)
                        let height = CGFloat(6 + (hash % 16))
                        let barProgress = Double(bar) / 18.0
                        let isHighlighted = barProgress <= playProgress
                        
                        RoundedRectangle(cornerRadius: 1)
                            .fill(isHighlighted
                                  ? (isFromMe ? PeakColors.black : PeakColors.accent)
                                  : (isFromMe ? PeakColors.black.opacity(0.25) : PeakColors.textSecondary)
                            )
                            .frame(width: 2, height: height)
                    }
                }
                .frame(height: 24)

                Text(durationText)
                    .font(PeakTypography.tiny)
                    .foregroundStyle(isFromMe ? PeakColors.black.opacity(0.6) : PeakColors.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isFromMe ? PeakColors.bubbleOut : PeakColors.bubbleIn)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var mediaIcon: String {
        switch message.type {
        case .image:  return "photo"
        case .video:  return "play.circle"
        case .circle: return "circle.circle"
        case .file:   return "doc"
        case .voice:  return "waveform"
        default:      return "paperclip"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func formatTimeSeconds(_ secs: Double) -> String {
        let mins = Int(secs) / 60
        let seconds = Int(secs) % 60
        return String(format: "%d:%02d", mins, seconds)
    }

    @ViewBuilder
    private func reactionsOverlay(_ msgReactions: [Reaction]) -> some View {
        let grouped = Dictionary(grouping: msgReactions, by: { $0.emoji })
        HStack(spacing: 4) {
            ForEach(grouped.map { ($0.key, $0.value.count) }, id: \.0) { emoji, count in
                HStack(spacing: 2) {
                    Text(emoji)
                        .font(.system(size: 11))
                    if count > 1 {
                        Text("\(count)")
                            .font(PeakTypography.tiny)
                            .foregroundStyle(isFromMe ? PeakColors.black : PeakColors.textPrimary)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isFromMe ? Color.white : Color(white: 0.18))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 1)
                .onTapGesture {
                    if let myId = appState.currentUser?.id {
                        if msgReactions.contains(where: { $0.emoji == emoji && $0.senderId == myId.uuidString }) {
                            appState.removeReaction(from: message.id, senderId: myId)
                        } else {
                            appState.addReaction(emoji, to: message.id, senderId: myId)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
        .offset(y: 12)
        .padding(.horizontal, 8)
    }
}

#Preview {
    ZStack {
        PeakColors.black.ignoresSafeArea()
        VStack {
            MessageBubbleView(message: .make("Hey! How do you like Peak so far?", from: User.alex.id, chatId: UUID(), offset: -120))
            MessageBubbleView(message: .make("It's incredibly fast and smooth. The animations are next level! \n\nAlso the design system is exactly what I wanted.", from: User.me.id, chatId: UUID(), offset: -60))
        }
        .padding(.vertical)
    }
    .preferredColorScheme(.dark)
}
