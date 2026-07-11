import SwiftUI

struct ChatListView: View {
    @State private var chats: [Chat] = Chat.mockChats
    
    var body: some View {
        NavigationStack {
            ZStack {
                PeakColors.pureBlack.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(chats) { chat in
                            NavigationLink(value: chat) {
                                ChatRowView(chat: chat)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .navigationDestination(for: Chat.self) { chat in
                    ChatDetailView(chat: chat)
                }
            }
            .navigationTitle("PEAK")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(PeakColors.primary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ChatListView()
}
