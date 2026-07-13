import Foundation
import Observation

// MARK: — AppState  (@Observable + @MainActor — Swift 6 concurrency-safe)

@MainActor
@Observable
final class AppState {

    // MARK: — Navigation & UI State
    var selectedTab: Tab = .chats
    var isUserAuthenticated: Bool = CacheService.shared.loadUser() != nil
    var viewingImageURL: URL? = nil

    // MARK: Data
    var chats: [Chat] = CacheService.shared.loadChats() ?? []
    var currentUser: User? = CacheService.shared.loadUser()
    var contacts: [User] = CacheService.shared.loadContacts() ?? []
    var isLoadingChats = false
    
    // Custom States (Reactions, Typing)
    var reactions: [UUID: [Reaction]] = CacheService.shared.loadReactions() ?? [:]
    var typingUsers: [UUID: Set<UUID>] = [:]

    func checkSession() async {
        for await (_, session) in AuthenticationService.shared.authStateChanges {
            if session != nil {
                if let userId = session?.user.id {
                    do {
                        let me: User = try await SupabaseManager.shared.client.from("users").select().eq("id", value: userId).single().execute().value
                        currentUser = me
                        isUserAuthenticated = true
                        CacheService.shared.saveUser(me)
                        await loadInitialData()
                    } catch {
                        print("Failed to fetch me: \(error)")
                        // Force logout if the profile doesn't exist in the database
                        try? await AuthenticationService.shared.signOut()
                        isUserAuthenticated = false
                        currentUser = nil
                        chats = []
                        contacts = []
                        CacheService.shared.clearAll()
                    }
                }
            } else {
                isUserAuthenticated = false
                currentUser = nil
                chats = []
                contacts = []
                CacheService.shared.clearAll()
            }
        }
    }

    func loadInitialData() async {
        isLoadingChats = true
        do {
            let allUsers = try await DatabaseService.shared.fetchAllUsers()
            // Exclude current user from contacts
            if let meId = currentUser?.id {
                self.contacts = allUsers.filter { $0.id != meId }
            } else {
                self.contacts = allUsers
            }
            CacheService.shared.saveContacts(self.contacts)
            
            self.chats = try await DatabaseService.shared.fetchMyChats()
            saveChatsToCache()
            
            // Start specific chat listeners
            startMessageListeners()
            startGlobalUserListener()
            
        } catch {
            print("Failed to load initial data: \(error)")
        }
        isLoadingChats = false
    }

    private var messageListenTasks: [UUID: Task<Void, Never>] = [:]

    private func startMessageListeners() {
        for chat in chats {
            listenToChat(chat.id)
        }
    }
    
    private func listenToChat(_ chatId: UUID) {
        guard messageListenTasks[chatId] == nil else { return }
        let task = Task {
            do {
                let stream = try await DatabaseService.shared.listenForMessages(in: chatId)
                for await message in stream {
                    handleIncomingMessage(message)
                }
            } catch {
                print("Listen error for chat \(chatId): \(error)")
            }
        }
        messageListenTasks[chatId] = task
    }
    
    private func startGlobalUserListener() {
        Task {
            do {
                let stream = try await DatabaseService.shared.listenForUserUpdates()
                for await user in stream {
                    if let idx = contacts.firstIndex(where: { $0.id == user.id }) {
                        contacts[idx] = user
                        CacheService.shared.saveContacts(contacts)
                    }
                    // Also update participants in chats
                    var chatsUpdated = false
                    for i in chats.indices {
                        if let pIdx = chats[i].participants.firstIndex(where: { $0.id == user.id }) {
                            chats[i].participants[pIdx] = user
                            chatsUpdated = true
                        }
                    }
                    if chatsUpdated {
                        saveChatsToCache()
                    }
                }
            } catch {
                print("User listen error: \(error)")
            }
        }
    }
    
    private func handleIncomingMessage(_ message: Message) {
        if let idx = chats.firstIndex(where: { $0.id == message.chatId }) {
            if let msgIdx = chats[idx].messages.firstIndex(where: { $0.id == message.id }) {
                // Update existing message
                chats[idx].messages[msgIdx] = message
            } else {
                // Append new message
                chats[idx].messages.append(message)
            }
            saveChatsToCache()
        } else {
            // New chat! We need to fetch it and add it.
            Task {
                do {
                    let allChats = try await DatabaseService.shared.fetchMyChats()
                    if let newChat = allChats.first(where: { $0.id == message.chatId }) {
                        self.chats.append(newChat)
                        saveChatsToCache()
                        listenToChat(newChat.id)
                    }
                } catch {
                    print("Failed to fetch new chat: \(error)")
                }
            }
        }
    }

    // MARK: Tab definition
    enum Tab: Hashable {
        case chats
        case contacts
        case profile
    }

    // MARK: — Chat helpers

    func chat(for id: UUID) -> Chat? {
        chats.first { $0.id == id }
    }

    func send(_ text: String, in chatId: UUID, replyToId: UUID? = nil) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let senderId = currentUser?.id else { return }
        let msg = Message(
            id: UUID(),
            chatId: chatId,
            senderId: senderId,
            type: .text,
            text: text,
            mediaUrl: nil,
            fileName: nil,
            fileSize: nil,
            duration: nil,
            timestamp: Date(),
            isRead: false,
            isEdited: false,
            replyToId: replyToId
        )
        send(msg)
    }
    
    func send(_ message: Message) {
        guard let idx = chats.firstIndex(where: { $0.id == message.chatId }) else { return }
        
        // Optimistic update
        chats[idx].messages.append(message)
        saveChatsToCache()
        
        Task {
            do {
                try await DatabaseService.shared.sendMessage(message)
            } catch {
                print("Failed to send message: \(error)")
            }
            triggerMockResponseIfNeeded(chatId: message.chatId)
        }
    }
    
    func updateMessage(_ message: Message) {
        guard let chatIdx = chats.firstIndex(where: { $0.id == message.chatId }),
              let msgIdx = chats[chatIdx].messages.firstIndex(where: { $0.id == message.id }) else { return }
        
        chats[chatIdx].messages[msgIdx] = message
        saveChatsToCache()
        
        Task {
            do {
                try await DatabaseService.shared.updateMessage(message)
            } catch {
                print("Failed to update message in DB: \(error)")
            }
        }
    }

    func markAllRead(in chatId: UUID) {
        guard let idx = chats.firstIndex(where: { $0.id == chatId }) else { return }
        
        var needsUpdate = false
        for i in chats[idx].messages.indices {
            if !chats[idx].messages[i].isRead && !chats[idx].messages[i].isFromMe(myId: currentUser?.id) {
                chats[idx].messages[i].isRead = true
                needsUpdate = true
            }
        }
        if needsUpdate {
            saveChatsToCache()
        }
        
        if needsUpdate, let myId = currentUser?.id {
            Task {
                do {
                    try await DatabaseService.shared.markMessagesAsRead(in: chatId, myId: myId)
                } catch {
                    print("Failed to mark messages as read in DB: \(error)")
                }
            }
        }
    }

    func loadMessages(for chatId: UUID, offset: Int = 0) async {
        guard let idx = chats.firstIndex(where: { $0.id == chatId }) else { return }
        do {
            let newMessages = try await DatabaseService.shared.fetchMessages(for: chatId, limit: 50, offset: offset)
            
            var current = chats[idx].messages
            let existingIds = Set(current.map { $0.id })
            
            for msg in newMessages {
                if !existingIds.contains(msg.id) {
                    current.append(msg)
                }
            }
            
            chats[idx].messages = current.sorted { $0.timestamp < $1.timestamp }
            saveChatsToCache()
        } catch {
            print("Failed to load messages: \(error)")
        }
    }

    func togglePin(chatId: UUID) {
        guard let idx = chats.firstIndex(where: { $0.id == chatId }) else { return }
        chats[idx].isPinned.toggle()
        saveChatsToCache()
    }

    func toggleMute(chatId: UUID) {
        guard let idx = chats.firstIndex(where: { $0.id == chatId }) else { return }
        chats[idx].isMuted.toggle()
        saveChatsToCache()
    }

    func deleteChat(chatId: UUID) {
        chats.removeAll { $0.id == chatId }
        saveChatsToCache()
        
        Task {
            do {
                try await DatabaseService.shared.deleteChatParticipant(chatId: chatId)
            } catch {
                print("Failed to delete chat participation: \(error)")
            }
        }
    }

    private var saveChatsTask: Task<Void, Never>?

    private func saveChatsToCache() {
        saveChatsTask?.cancel()
        let currentChats = self.chats
        saveChatsTask = Task.detached {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            CacheService.shared.saveChats(currentChats)
        }
    }

    var totalUnread: Int { chats.reduce(0) { $0 + $1.unreadCount(myId: currentUser?.id) } }

    // MARK: — Reactions & Typing Indicator Simulation

    func setTyping(userId: UUID, in chatId: UUID, isTyping: Bool) {
        if isTyping {
            var currentSet = typingUsers[chatId] ?? []
            currentSet.insert(userId)
            typingUsers[chatId] = currentSet
        } else {
            typingUsers[chatId]?.remove(userId)
            if typingUsers[chatId]?.isEmpty == true {
                typingUsers.removeValue(forKey: chatId)
            }
        }
    }

    func addReaction(_ emoji: String, to messageId: UUID, senderId: UUID) {
        let reaction = Reaction(id: UUID().uuidString, emoji: emoji, senderId: senderId.uuidString)
        var list = reactions[messageId, default: []]
        list.removeAll { $0.senderId == senderId.uuidString }
        list.append(reaction)
        reactions[messageId] = list
        CacheService.shared.saveReactions(reactions)
    }

    func removeReaction(from messageId: UUID, senderId: UUID) {
        reactions[messageId]?.removeAll { $0.senderId == senderId.uuidString }
        if reactions[messageId]?.isEmpty == true {
            reactions.removeValue(forKey: messageId)
        }
        CacheService.shared.saveReactions(reactions)
    }

    func simulateMockTyping(for chatId: UUID) {
        guard let chat = chat(for: chatId),
              let mockUser = chat.otherParticipant(myId: currentUser?.id),
              mockUser.id != currentUser?.id else { return }
              
        let mockIds = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, // Alex
            UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, // Sam
            UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, // Nina
            UUID(uuidString: "00000000-0000-0000-0000-000000000005")!  // Jay
        ]
        guard mockIds.contains(mockUser.id) else { return }

        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            
            setTyping(userId: mockUser.id, in: chatId, isTyping: true)
            
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            
            setTyping(userId: mockUser.id, in: chatId, isTyping: false)
        }
    }

    func triggerMockResponseIfNeeded(chatId: UUID) {
        guard let chat = chat(for: chatId),
              let mockUser = chat.otherParticipant(myId: currentUser?.id),
              mockUser.id != currentUser?.id else { return }
              
        let mockReplies = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!: "О, привет! Как дела? Рад слышать.",
            UUID(uuidString: "00000000-0000-0000-0000-000000000003")!: "Отличный дизайн! Кофе готов ☕️",
            UUID(uuidString: "00000000-0000-0000-0000-000000000004")!: "Темная тема просто супер. Отправляю макеты...",
            UUID(uuidString: "00000000-0000-0000-0000-000000000005")!: "Йоу! Давай созвонимся позже 👍"
        ]
        
        guard let replyText = mockReplies[mockUser.id] else { return }
        
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            
            setTyping(userId: mockUser.id, in: chatId, isTyping: true)
            
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            
            setTyping(userId: mockUser.id, in: chatId, isTyping: false)
            
            let replyMsg = Message(
                id: UUID(),
                chatId: chatId,
                senderId: mockUser.id,
                type: .text,
                text: replyText,
                mediaUrl: nil,
                fileName: nil,
                fileSize: nil,
                duration: nil,
                timestamp: Date(),
                isRead: false,
                isEdited: false,
                replyToId: chat.messages.last?.id
            )
            
            if let idx = chats.firstIndex(where: { $0.id == chatId }) {
                chats[idx].messages.append(replyMsg)
                saveChatsToCache()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}
