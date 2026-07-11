import SwiftUI

struct ChatDetailView: View {
    let chat: Chat
    @State private var messageText: String = ""
    
    // In a real app we'd observe the DB. For now, use local state for testing.
    @State private var messages: [Message] = []
    
    var body: some View {
        ZStack {
            PeakColors.pureBlack.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(spacing: 8) {
                            ForEach(messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.top, 16)
                        .onAppear {
                            messages = chat.messages
                            if let last = messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: messages) { _ in
                            if let last = messages.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                // Input Area
                HStack(spacing: 12) {
                    Button(action: {
                        // Attachment action
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(PeakColors.primary)
                    }
                    
                    TextField("Message", text: $messageText)
                        .font(PeakTypography.body)
                        .foregroundColor(PeakColors.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(PeakColors.bubbleGray)
                        .cornerRadius(20)
                    
                    if !messageText.isEmpty {
                        Button(action: {
                            sendMessage()
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(PeakColors.primary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(PeakColors.pureBlack)
            }
        }
        .navigationTitle(chat.otherParticipant?.username ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        // Ensure nav bar is properly styled in dark mode (usually handled automatically if scheme is dark)
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let newMsg = Message(id: UUID().uuidString, senderId: User.mockMe.id, text: messageText, timestamp: Date(), isRead: true)
        messages.append(newMsg)
        messageText = ""
    }
}

#Preview {
    NavigationView {
        ChatDetailView(chat: Chat.mockChats[0])
            .preferredColorScheme(.dark)
    }
}
