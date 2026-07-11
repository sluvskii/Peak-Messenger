import SwiftUI

struct ChatRowView: View {
    let chat: Chat
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(PeakColors.bubbleGray)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(chat.otherParticipant?.username.prefix(1).uppercased() ?? "")
                        .font(PeakTypography.title.weight(.semibold))
                        .foregroundColor(PeakColors.primary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.otherParticipant?.username ?? "Unknown")
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundColor(PeakColors.primary)
                    
                    Spacer()
                    
                    if let lastMessage = chat.lastMessage {
                        Text(formatDate(lastMessage.timestamp))
                            .font(PeakTypography.caption)
                            .foregroundColor(PeakColors.secondary)
                    }
                }
                
                if let lastMessage = chat.lastMessage {
                    Text(lastMessage.text)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(PeakColors.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(PeakColors.pureBlack)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ChatRowView(chat: Chat.mockChats[0])
        .preferredColorScheme(.dark)
}
