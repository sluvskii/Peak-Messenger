import Foundation
import Observation

// MARK: — AppState  (@Observable + @MainActor — Swift 6 concurrency-safe)

@MainActor
@Observable
final class AppState {

    // MARK: Navigation
    var selectedTab: Tab = .chats

    // MARK: Session
    var isUserAuthenticated = false

    // MARK: Data
    var chats: [Chat] = []
    var currentUser: User?
    var contacts: [User] = []

    func checkSession() async {
        for await (_, session) in AuthenticationService.shared.authStateChanges {
            if session != nil {
                if let userId = session?.user.id {
                    do {
                        let me: User = try await SupabaseManager.shared.client.from("users").select().eq("id", value: userId).single().execute().value
                        currentUser = me
                        isUserAuthenticated = true
                        await loadInitialData()
                    } catch {
                        print("Failed to fetch me: \(error)")
                        // Force logout if the profile doesn't exist in the database
                        try? await AuthenticationService.shared.signOut()
                        isUserAuthenticated = false
                        currentUser = nil
                        chats = []
                        contacts = []
                    }
                }
            } else {
                isUserAuthenticated = false
                currentUser = nil
                chats = []
                contacts = []
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
            
            self.chats = try await DatabaseService.shared.fetchMyChats()
            
            // Listen for messages in all chats
            for chat in self.chats {
                Task {
                    do {
                        for try await message in try await DatabaseService.shared.listenForMessages(in: chat.id) {
                            if let idx = self.chats.firstIndex(where: { $0.id == chat.id }) {
                                // append message if it doesn't already exist
                                if !self.chats[idx].messages.contains(where: { $0.id == message.id }) {
                                    self.chats[idx].messages.append(message)
                                }
                            }
                        }
                    } catch {
                        print("Listen messages error: \(error)")
                    }
                }
            }
        } catch {
            print("Failed to load initial data: \(error)")
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

    func send(_ text: String, in chatId: UUID) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let idx = chats.firstIndex(where: { $0.id == chatId }),
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
            replyToId: nil
        )
        // Optimistic update
        chats[idx].messages.append(msg)
        
        Task {
            do {
                try await DatabaseService.shared.sendMessage(msg)
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }

    func markAllRead(in chatId: UUID) {
        guard let idx = chats.firstIndex(where: { $0.id == chatId }) else { return }
        for i in chats[idx].messages.indices {
            chats[idx].messages[i].isRead = true
        }
    }

    func togglePin(chatId: UUID) {
        guard let idx = chats.firstIndex(where: { $0.id == chatId }) else { return }
        chats[idx].isPinned.toggle()
    }

    func toggleMute(chatId: UUID) {
        guard let idx = chats.firstIndex(where: { $0.id == chatId }) else { return }
        chats[idx].isMuted.toggle()
    }

    func deleteChat(chatId: UUID) {
        chats.removeAll { $0.id == chatId }
    }



    var totalUnread: Int { chats.reduce(0) { $0 + $1.unreadCount(myId: currentUser?.id) } }
}
