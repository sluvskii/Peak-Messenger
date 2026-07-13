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
    enum RecordingState {
        case none
        case holding
        case locked
    }
    var voiceManager = VoiceMessageManager.shared
    @State private var dragOffset: CGSize = .zero
    @State private var recordingState: RecordingState = .none
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

    private var inputBar: some View {
        let uploading = isUploadingMedia
        
        return HStack(alignment: .bottom, spacing: 10) {
            if recordingState == .none {
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
                .transition(.move(edge: .leading).combined(with: .opacity))

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
                .transition(.move(edge: .leading).combined(with: .opacity))
                
            } else if recordingState == .holding {
                // Left side: Centiseconds timer and swipe to cancel label
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(PeakColors.textPrimary)
                            .opacity(voiceManager.recordingDuration.truncatingRemainder(dividingBy: 1) > 0.5 ? 1.0 : 0.3)
                        
                        Text(formatTelegramDuration(voiceManager.recordingDuration))
                            .font(PeakTypography.bodyMedium)
                            .foregroundStyle(PeakColors.textPrimary)
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PeakColors.textSecondary)
                        
                        Text("Влево — отмена")
                            .font(PeakTypography.body)
                            .foregroundStyle(PeakColors.textSecondary)
                    }
                    .opacity(max(0.1, 1.0 - Double(abs(dragOffset.width)) / 100.0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .offset(x: min(0, dragOffset.width * 0.8))
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
            } else if recordingState == .locked {
                // Delete button
                Button {
                    cancelAndDiscardRecording()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundStyle(PeakColors.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive(), in: Circle())
                .transition(.scale.combined(with: .opacity))

                // Lock recording view
                HStack(spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(PeakColors.textPrimary)
                        .opacity(voiceManager.recordingDuration.truncatingRemainder(dividingBy: 1) > 0.5 ? 1.0 : 0.3)
                    
                    Text(formatTelegramDuration(voiceManager.recordingDuration))
                        .font(PeakTypography.bodyMedium)
                        .foregroundStyle(PeakColors.textPrimary)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text("Запись...")
                        .font(PeakTypography.body)
                        .foregroundStyle(PeakColors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            // Persistent Button on the right
            Group {
                if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && recordingState == .none {
                    // standard send button
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
                } else if recordingState == .locked {
                    // locked mode send button
                    Button {
                        stopAndSendVoiceMessage()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(PeakColors.black)
                            .frame(width: 44, height: 44)
                            .background(Color.white, in: Circle())
                    }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    // Persistent Voice Recording Button
                    Button {
                    } label: {
                        ZStack {
                            if recordingState == .holding {
                                let currentLevel = CGFloat(voiceManager.audioLevels.last ?? 0.1)
                                
                                // White pulsing waves (outer)
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 90, height: 90)
                                    .scaleEffect(1.0 + currentLevel * 1.5)
                                    .animation(.easeOut(duration: 0.15), value: currentLevel)
                                
                                // White pulsing waves (inner)
                                Circle()
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: 70, height: 70)
                                    .scaleEffect(1.0 + currentLevel * 1.1)
                                    .animation(.easeOut(duration: 0.15), value: currentLevel)
                                
                                // Massive white circle with black mic icon
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(PeakColors.black)
                                    .frame(width: 56, height: 56)
                                    .background(Color.white, in: Circle())
                            } else {
                                // Standard mic button appearance
                                Image(systemName: "mic")
                                    .font(.system(size: 19))
                                    .foregroundStyle(PeakColors.textPrimary)
                                    .frame(width: 44, height: 44)
                                    .glassEffect(.regular.interactive(), in: Circle())
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(RecordButtonStyle(onPressChanged: { isPressed in
                        if isPressed {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                recordingState = .holding
                                dragOffset = .zero
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task {
                                await voiceManager.startRecording()
                            }
                        } else {
                            if recordingState == .holding {
                                stopAndSendVoiceMessage()
                            }
                        }
                    }))
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard recordingState == .holding else { return }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = value.translation
                                }
                                
                                // 1. Horizontal swipe-to-cancel check
                                if value.translation.width < -100 {
                                    cancelAndDiscardRecording()
                                }
                                
                                // 2. Vertical swipe-to-lock check
                                if value.translation.height < -65 {
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.58)) { // Bouncy spring back
                                        recordingState = .locked
                                        dragOffset = .zero
                                    }
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                }
                            }
                    )
                    // Button physically follows finger in 2D space!
                    .offset(
                        x: recordingState == .holding ? min(0, dragOffset.width) : 0,
                        y: recordingState == .holding ? min(0, dragOffset.height) : 0
                    )
                    .overlay(alignment: .top) {
                        if recordingState == .holding {
                            let distance = abs(dragOffset.height)
                            let isClose = dragOffset.height < -40
                            
                            VStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(isClose ? PeakColors.textPrimary : PeakColors.textSecondary)
                                    .scaleEffect(isClose ? 1.25 : 1.0)
                                
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(PeakColors.textSecondary)
                                    .offset(y: voiceManager.recordingDuration.truncatingRemainder(dividingBy: 1) > 0.5 ? -3 : 0)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: voiceManager.recordingDuration)
                            }
                            .frame(width: 36, height: 60)
                            .glassEffect(.regular.interactive(), in: Capsule())
                            .offset(y: -75)
                            .opacity(max(0.0, 1.0 - Double(abs(dragOffset.width)) / 50.0))
                            .scaleEffect(max(0.7, 1.0 - (distance / 200.0)))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .background(Color.clear)
    }

    private func formatTelegramDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let centiseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d,%02d", minutes, seconds, centiseconds)
    }

    private func cancelAndDiscardRecording() {
        voiceManager.cancelRecording()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            recordingState = .none
            dragOffset = .zero
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func stopAndSendVoiceMessage() {
        guard let (url, duration) = voiceManager.stopRecording() else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            recordingState = .none
            dragOffset = .zero
        }
        
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

struct RecordButtonStyle: ButtonStyle {
    let onPressChanged: (Bool) -> Void
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                onPressChanged(newValue)
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
