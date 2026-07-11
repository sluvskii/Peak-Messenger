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
            
            // Start global listeners
            startGlobalMessageListener()
            startGlobalUserListener()
            
        } catch {
            print("Failed to load initial data: \(error)")
        }
    }

    private func startGlobalMessageListener() {
        Task {
            do {
                let stream = try await DatabaseService.shared.listenForAllMessages()
                for await message in stream {
                    handleIncomingMessage(message)
                }
            } catch {
                print("Global listen error: \(error)")
            }
        }
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

    private func saveChatsToCache() {
        let currentChats = self.chats
        Task.detached {
            CacheService.shared.saveChats(currentChats)
        }
    }



    var totalUnread: Int { chats.reduce(0) { $0 + $1.unreadCount(myId: currentUser?.id) } }
}
