import SwiftUI

// MARK: — Chat Detail Screen

struct ChatDetailView: View {
    let chat: Chat
    @Environment(AppState.self) private var appState

    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @FocusState private var isInputFocused: Bool

    private var messages: [Message] {
        appState.chat(for: chat.id)?.sortedMessages ?? chat.sortedMessages
    }

    private var participant: User { chat.otherParticipant ?? .alex }

    var body: some View {
        ZStack {
            PeakColors.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Message list
                messageList

                // Input bar
                inputBar
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { navBarContent }
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            appState.markAllRead(in: chat.id)
        }
    }

    // MARK: — Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .push(from: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                scrollProxy = proxy
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy, animated: true)
            }
        }
    }

    // MARK: — Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            PeakDivider()

            HStack(alignment: .bottom, spacing: 10) {
                // Attachment
                Button {
                    // future: show attachment picker
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(PeakColors.textSecondary)
                        .frame(width: 36, height: 36)
                }

                // Text field
                TextField("Message", text: $messageText, axis: .vertical)
                    .font(PeakTypography.body)
                    .foregroundStyle(PeakColors.textPrimary)
                    .lineLimit(1...6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(PeakColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .focused($isInputFocused)

                // Send / voice button
                if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        // future: record voice
                    } label: {
                        Image(systemName: "mic")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(PeakColors.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                } else {
                    Button {
                        send()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(PeakColors.black)
                            .frame(width: 34, height: 34)
                            .background(PeakColors.textPrimary)
                            .clipShape(Circle())
                    }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(PeakColors.black)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: messageText.isEmpty)
        }
    }

    // MARK: — Nav bar

    @ToolbarContentBuilder
    private var navBarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Button {
                // open profile detail
            } label: {
                VStack(spacing: 2) {
                    Text(participant.username)
                        .font(PeakTypography.headline)
                        .foregroundStyle(PeakColors.textPrimary)
                    Text(participant.lastSeenText)
                        .font(PeakTypography.tiny)
                        .foregroundStyle(PeakColors.textSecondary)
                }
            }
            .buttonStyle(.plain)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            AvatarView(user: participant, size: 32, showOnline: true)
        }
    }

    // MARK: — Helpers

    private func send() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            appState.send(trimmed, in: chat.id)
        }
        messageText = ""
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let last = messages.last else { return }
        if animated {
            withAnimation(.spring(duration: 0.4)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(chat: Chat.mockChats[0])
            .environment(AppState())
    }
    .preferredColorScheme(.dark)
}
