import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromMe {
                Spacer()
            }
            
            Text(message.text)
                .font(PeakTypography.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .foregroundColor(message.isFromMe ? PeakColors.pureBlack : PeakColors.pureWhite)
                .background(message.isFromMe ? PeakColors.pureWhite : PeakColors.bubbleGray)
                .clipShape(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                // Add a subtle border for incoming messages if the background is truly black
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PeakColors.tertiary, lineWidth: message.isFromMe ? 0 : 0.5)
                )
            
            if !message.isFromMe {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

#Preview {
    ZStack {
        PeakColors.pureBlack.ignoresSafeArea()
        VStack {
            MessageBubbleView(message: Message(id: "1", senderId: User.mockMe.id, text: "Hello there!", timestamp: Date(), isRead: true))
            MessageBubbleView(message: Message(id: "2", senderId: User.mockFriend.id, text: "Hi! How are you?", timestamp: Date(), isRead: true))
        }
    }
}
