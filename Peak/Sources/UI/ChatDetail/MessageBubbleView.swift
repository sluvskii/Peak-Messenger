import SwiftUI

// MARK: — Message Bubble

struct MessageBubbleView: View {
    let message: Message

    private var isFromMe: Bool { message.isFromMe }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                bubbleBody
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
            Text(message.displayText)
                .font(PeakTypography.body)
                .foregroundStyle(isFromMe ? PeakColors.black : PeakColors.textPrimary)
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

        case .image, .video, .circle, .file, .voice:
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
                Text("edited")
                    .font(PeakTypography.tiny)
                    .foregroundStyle(PeakColors.textTertiary)
            }
        }
    }

    // MARK: — Helpers

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
}

#Preview {
    ZStack {
        PeakColors.black.ignoresSafeArea()
        VStack(spacing: 0) {
            MessageBubbleView(message: .make("Hey! How do you like Peak so far?", from: User.alex.id, chatId: "c1", offset: -120))
            MessageBubbleView(message: .make("It's incredible. Clean, fast, beautiful.", from: User.me.id, chatId: "c1", offset: -60))
            MessageBubbleView(message: .make("Right? Nothing like it.", from: User.alex.id, chatId: "c1", offset: -30))
        }
        .padding(.vertical)
    }
    .preferredColorScheme(.dark)
}
