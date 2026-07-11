import SwiftUI

// MARK: — Chat Detail Screen

struct ChatDetailView: View {
    let chat: Chat
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @FocusState private var isInputFocused: Bool

    private var messages: [Message] {
        appState.chat(for: chat.id)?.sortedMessages ?? chat.sortedMessages
    }

    private var participant: User { chat.otherParticipant ?? .alex }

    var body: some View {
        ZStack(alignment: .top) {
            PeakColors.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Message list
                messageList

                // Input bar
                inputBar
            }

            // Floating Header
            floatingHeader
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            appState.markAllRead(in: chat.id)
        }
    }

    // MARK: — Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Push content below floating header
                Spacer().frame(height: 110)
                
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
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea()
            .onAppear {
                scrollProxy = proxy
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy, animated: true)
            }
        }
    }

    // MARK: — Floating Header

    private var floatingHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PeakColors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Circle())
            }

            HStack(spacing: 10) {
                AvatarView(user: participant, size: 36, showOnline: true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.username)
                        .font(PeakTypography.headline)
                        .foregroundStyle(PeakColors.textPrimary)
                    Text(participant.lastSeenText)
                        .font(PeakTypography.tiny)
                        .foregroundStyle(PeakColors.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            
            Button {
                // Audio/Video call action
            } label: {
                Image(systemName: "phone")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PeakColors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 60) // Safe area inset
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [PeakColors.black, PeakColors.black.opacity(0.8), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }

    // MARK: — Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 8) // SafeArea will be handled automatically by SwiftUI keyboard avoidance
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
