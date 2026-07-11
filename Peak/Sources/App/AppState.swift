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
    var chats: [Chat] = Chat.mockChats
    var currentUser: User?

    func checkSession() async {
        for await (event, session) in AuthenticationService.shared.authStateChanges {
            isUserAuthenticated = session != nil
            if session != nil {
                // We will fetch the user from Supabase here later
                currentUser = .me
            } else {
                currentUser = nil
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
            reactions: [],
            timestamp: Date(),
            isRead: false,
            isEdited: false,
            replyToId: nil
        )
        chats[idx].messages.append(msg)
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

    var contacts: [User] { User.allContacts }

    var totalUnread: Int { chats.reduce(0) { $0 + $1.unreadCount } }
}
