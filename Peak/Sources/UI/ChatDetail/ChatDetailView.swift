import SwiftUI
import PhotosUI

// MARK: — Chat Detail Screen

@MainActor
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
    
    // Voice Message states
    private var voiceManager = VoiceMessageManager.shared
    @State private var dragOffset: CGFloat = 0
    @State private var hasStartedRecording = false
    @State private var isShowingInfo = false

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
        .navigationDestination(isPresented: $isShowingInfo) {
            ChatInfoView(chat: chat)
                .environment(appState)
        }
        .onAppear {
            appState.markAllRead(in: chat.id)
            appState.simulateMockTyping(for: chat.id)
            Task {
                await appState.loadMessages(for: chat.id)
            }
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
                                Section("Реакция") {
                                    Button("❤️") { react("❤️", to: message) }
                                    Button("👍") { react("👍", to: message) }
                                    Button("🔥") { react("🔥", to: message) }
                                    Button("😂") { react("😂", to: message) }
                                    Button("😢") { react("😢", to: message) }
                                    Button("👏") { react("👏", to: message) }
                                }
                                
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
                            .onAppear {
                                if message.id == messages.first?.id && messages.count >= 50 {
                                    Task {
                                        await appState.loadMessages(for: chat.id, offset: messages.count)
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

    // MARK: — Input Bar

    private var inputBar: some View {
        let uploading = isUploadingMedia
        let recording = voiceManager.isRecording
        
        return VStack(spacing: 0) {
            PeakDivider()

            HStack(alignment: .bottom, spacing: 10) {
                if recording {
                    recordingHUD
                    
                    // Mic button (held down during recording)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .scaleEffect(hasStartedRecording ? 1.2 : 1.0)
                        .animation(.spring(duration: 0.2), value: hasStartedRecording)
                        .gesture(recordGesture)
                } else {
                    // Attachment
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        if uploading {
                            ProgressView()
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(PeakColors.textSecondary)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .disabled(uploading)

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
                        Image(systemName: "mic")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(PeakColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                            .gesture(recordGesture)
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(PeakColors.black)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: recording)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: messageText.isEmpty)
        }
    }

    private var recordingHUD: some View {
        HStack(spacing: 12) {
            // Pulsing dot
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(.red)
                .opacity(voiceManager.recordingDuration.truncatingRemainder(dividingBy: 1) > 0.5 ? 1.0 : 0.2)
            
            Text(formatDuration(voiceManager.recordingDuration))
                .font(PeakTypography.bodyMedium)
                .foregroundStyle(PeakColors.textPrimary)
                .monospacedDigit()
            
            // Audio levels visualization
            HStack(spacing: 2) {
                ForEach(0..<voiceManager.audioLevels.count, id: \.self) { index in
                    let level = CGFloat(voiceManager.audioLevels[index])
                    RoundedRectangle(cornerRadius: 1)
                        .fill(PeakColors.textSecondary)
                        .frame(width: 2, height: max(3, 20 * level))
                }
            }
            .frame(height: 30)
            
            Spacer()
            
            Text(dragOffset < -60 ? "Отпустите" : "< Смахните")
                .font(PeakTypography.caption)
                .foregroundStyle(dragOffset < -60 ? .red : PeakColors.textSecondary)
                .offset(x: dragOffset)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(PeakColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var recordGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragOffset = value.translation.width
                if !hasStartedRecording {
                    hasStartedRecording = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task {
                        await voiceManager.startRecording()
                    }
                }
            }
            .onEnded { value in
                hasStartedRecording = false
                let offset = value.translation.width
                if offset < -70 {
                    voiceManager.cancelRecording()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } else {
                    stopAndSendVoiceMessage()
                }
                dragOffset = 0
            }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func stopAndSendVoiceMessage() {
        guard let (url, duration) = voiceManager.stopRecording() else { return }
        if duration < 1.0 {
            print("Voice message too short, discarded")
            return
        }
        
        Task {
            do {
                guard let data = try? Data(contentsOf: url) else { return }
                guard let userId = appState.currentUser?.id else { return }
                
                let path = "\(chat.id)/\(UUID().uuidString).m4a"
                let serverURL = try await StorageService.shared.uploadMedia(data, bucket: "messages", path: path, contentType: "audio/m4a")
                
                let msg = Message(
                    id: UUID(),
                    chatId: chat.id,
                    senderId: userId,
                    type: .voice,
                    text: nil,
                    mediaUrl: serverURL.absoluteString,
                    fileName: "Golosovoe.m4a",
                    fileSize: data.count,
                    duration: duration,
                    timestamp: Date(),
                    isRead: false,
                    isEdited: false,
                    replyToId: replyingMessage?.id
                )
                
                appState.send(msg)
                replyingMessage = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                print("Failed to send voice message: \(error)")
                uploadError = error.localizedDescription
                showUploadError = true
            }
        }
    }

    // MARK: — Nav bar

    @ToolbarContentBuilder
    private var navBarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Button {
                isShowingInfo = true
            } label: {
                VStack(spacing: 2) {
                    Text(participant.username)
                        .font(PeakTypography.headline)
                        .foregroundStyle(PeakColors.textPrimary)
                    if let typingIds = appState.typingUsers[chat.id], !typingIds.isEmpty {
                        Text("печатает...")
                            .font(PeakTypography.tiny)
                            .foregroundStyle(PeakColors.accent)
                    } else {
                        Text(participant.lastSeenText)
                            .font(PeakTypography.tiny)
                            .foregroundStyle(PeakColors.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            AvatarView(user: participant, size: 32, showOnline: true)
        }
    }

    // MARK: — Helpers

    private func react(_ emoji: String, to message: Message) {
        if let myId = appState.currentUser?.id {
            if let existing = appState.reactions[message.id], existing.contains(where: { $0.emoji == emoji && $0.senderId == myId.uuidString }) {
                appState.removeReaction(from: message.id, senderId: myId)
            } else {
                appState.addReaction(emoji, to: message.id, senderId: myId)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

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
        
        // Compress image if possible
        let uploadData: Data
        if let image = UIImage(data: data), let compressed = image.jpegData(compressionQuality: 0.6) {
            uploadData = compressed
        } else {
            uploadData = data
        }
        
        isUploadingMedia = true
        do {
            let path = "\(chat.id)/\(UUID().uuidString).jpg"
            let url = try await StorageService.shared.uploadMedia(uploadData, bucket: "messages", path: path, contentType: "image/jpeg")
            
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
