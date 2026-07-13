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
    var voiceManager = VoiceMessageManager.shared
    @State private var dragOffset: CGFloat = 0
    @State private var hasStartedRecording = false
    @State private var isShowingInfo = false

    init(chat: Chat) {
        self.chat = chat
    }

    private var messages: [Message] {
        appState.chat(for: chat.id)?.sortedMessages ?? chat.sortedMessages
    }

    private var participant: User { chat.otherParticipant(myId: appState.currentUser?.id) ?? .alex }

    var body: some View {
        ZStack {
            PeakColors.black.ignoresSafeArea()

            messageList
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        // Editing banner
                        if let editing = editingMessage {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
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
                            .padding(.vertical, 10)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .padding(.horizontal, 14)
                            .padding(.bottom, 8)
                        }

                        // Replying banner
                        if let replying = replyingMessage {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
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
                            .padding(.vertical, 10)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .padding(.horizontal, 14)
                            .padding(.bottom, 8)
                        }

                        inputBar
                    }
                    .background(Color.clear)
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
        
        return HStack(alignment: .bottom, spacing: 10) {
            if recording {
                recordingHUD
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                
                // Mic button (held down during recording)
                Image(systemName: "mic.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.red)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .scaleEffect(hasStartedRecording ? 1.25 : 1.0)
                    .animation(.spring(duration: 0.2), value: hasStartedRecording)
                    .gesture(recordGesture)
            } else {
                // Attachment Button
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        if uploading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(PeakColors.textPrimary)
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive(), in: Circle())
                .disabled(uploading)
                .buttonStyle(PressButtonStyle())

                // Text field
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Сообщение", text: $messageText, axis: .vertical)
                        .font(PeakTypography.body)
                        .foregroundStyle(PeakColors.textPrimary)
                        .lineLimit(1...6)
                        .focused($isInputFocused)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                // Send / voice button
                Group {
                    if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "mic")
                            .font(.system(size: 19))
                            .foregroundStyle(PeakColors.textPrimary)
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: Circle())
                            .contentShape(Rectangle())
                            .gesture(recordGesture)
                    } else {
                        Button {
                            send()
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(PeakColors.black)
                                .frame(width: 44, height: 44)
                                .background(PeakColors.textPrimary, in: Circle())
                        }
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .background(Color.clear)
        .animation(.spring(duration: 0.25, bounce: 0.3), value: recording)
        .animation(.spring(duration: 0.25, bounce: 0.3), value: messageText.isEmpty)
    }

    private var recordingHUD: some View {
        HStack(spacing: 12) {
            // Pulsing dot + Duration
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.red)
                    .opacity(voiceManager.recordingDuration.truncatingRemainder(dividingBy: 1) > 0.5 ? 1.0 : 0.3)
                
                Text(formatDuration(voiceManager.recordingDuration))
                    .font(PeakTypography.bodyMedium)
                    .foregroundStyle(PeakColors.textPrimary)
                    .monospacedDigit()
            }
            
            // Audio levels visualization (fixed width to prevent layout shifting)
            HStack(spacing: 2.5) {
                ForEach(0..<voiceManager.audioLevels.count, id: \.self) { index in
                    let level = CGFloat(voiceManager.audioLevels[index])
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(PeakColors.textPrimary)
                        .frame(width: 3, height: max(4, 24 * level))
                }
            }
            .frame(width: 70, height: 30)
            
            Spacer()
            
            // Cancel swipe gesture indicator (no wrapping, animated chevron)
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PeakColors.textSecondary)
                    .offset(x: voiceManager.recordingDuration.truncatingRemainder(dividingBy: 1) > 0.5 ? -3 : 0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: voiceManager.recordingDuration)
                
                Text("Отмена")
                    .font(PeakTypography.caption)
                    .foregroundStyle(dragOffset < -60 ? .red : PeakColors.textSecondary)
            }
            .offset(x: dragOffset)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
