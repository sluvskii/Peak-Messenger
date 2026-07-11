import SwiftUI
import PhotosUI

// MARK: — Chat Detail Screen

struct ChatDetailView: View {
    let chat: Chat
    @Environment(AppState.self) private var appState

    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @FocusState private var isInputFocused: Bool
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isUploadingMedia = false
    
    @State private var editingMessage: Message? = nil
    @State private var replyingMessage: Message? = nil
    
    @State private var showUploadError = false
    @State private var uploadError = ""

    private var messages: [Message] {
        appState.chat(for: chat.id)?.sortedMessages ?? chat.sortedMessages
    }

    private var participant: User { chat.otherParticipant(myId: appState.currentUser?.id) ?? .alex }

    var body: some View {
        ZStack {
            PeakColors.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Message list
                messageList

                // Editing banner
                if let editing = editingMessage {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Редактирование")
                                .font(PeakTypography.caption)
                                .foregroundStyle(PeakColors.accent)
                            Text(editing.displayText)
                                .font(PeakTypography.body)
                                .foregroundStyle(PeakColors.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            editingMessage = nil
                            messageText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(PeakColors.textTertiary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(PeakColors.surface)
                }

                // Replying banner
                if let replying = replyingMessage {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(appState.chat(for: chat.id)?.participants.first(where: { $0.id == replying.senderId })?.username ?? "Ответ")
                                .font(PeakTypography.caption)
                                .foregroundStyle(PeakColors.accent)
                            Text(replying.displayText)
                                .font(PeakTypography.body)
                                .foregroundStyle(PeakColors.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            replyingMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(PeakColors.textTertiary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(PeakColors.surface)
                }

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
        .onChange(of: selectedItem) { _, newItem in
            Task {
                await handleMediaSelection(newItem)
            }
        }
        .alert("Ошибка загрузки", isPresented: $showUploadError) {
            Button("Ок", role: .cancel) { }
        } message: {
            Text(uploadError)
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
                            .contextMenu {
                                Button {
                                    replyingMessage = message
                                    isInputFocused = true
                                } label: {
                                    Label("Ответить", systemImage: "arrowshape.turn.up.left")
                                }
                                
                                if message.isFromMe(myId: appState.currentUser?.id) {
                                    if message.type == .text {
                                        Button {
                                            editingMessage = message
                                            messageText = message.text ?? ""
                                            isInputFocused = true
                                        } label: {
                                            Label("Редактировать", systemImage: "pencil")
                                        }
                                    }
                                    Button(role: .destructive) {
                                        deleteMessage(message)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
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
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    if isUploadingMedia {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(PeakColors.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                }
                .disabled(isUploadingMedia)

                // Text field
                TextField("Сообщение", text: $messageText, axis: .vertical)
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
        messageText = ""
        
        if let editing = editingMessage {
            var updatedMessage = editing
            updatedMessage.text = trimmed
            updatedMessage.isEdited = true
            
            appState.updateMessage(updatedMessage)
            editingMessage = nil
        } else {
            appState.send(trimmed, in: chat.id, replyToId: replyingMessage?.id)
            replyingMessage = nil
        }
    }
    
    private func deleteMessage(_ message: Message) {
        var deletedMsg = message
        deletedMsg.type = .deleted
        deletedMsg.text = "Сообщение удалено"
        appState.updateMessage(deletedMsg)
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
    
    private func handleMediaSelection(_ item: PhotosPickerItem?) async {
        guard let item = item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let userId = appState.currentUser?.id else { return }
        
        isUploadingMedia = true
        do {
            let path = "\(chat.id)/\(UUID().uuidString).jpg"
            let url = try await StorageService.shared.uploadMedia(data, bucket: "messages", path: path, contentType: "image/jpeg")
            
            // Create and send image message
            let msg = Message(
                id: UUID(),
                chatId: chat.id,
                senderId: userId,
                type: .image,
                text: "",
                mediaUrl: url.absoluteString,
                fileName: nil,
                fileSize: Int(data.count),
                duration: nil,
                timestamp: Date(),
                isRead: false,
                isEdited: false,
                replyToId: replyingMessage?.id
            )
            
            appState.send(msg) // We need to update AppState to handle full message sending
            replyingMessage = nil
        } catch {
            print("Failed to upload media: \(error)")
            uploadError = error.localizedDescription
            showUploadError = true
        }
        isUploadingMedia = false
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(chat: Chat.mockChats[0])
            .environment(AppState())
    }
    .preferredColorScheme(.dark)
}
