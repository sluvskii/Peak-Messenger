import Foundation

// MARK: — Chat

struct Chat: Identifiable, Hashable, Codable {
    let id: String
    let participants: [User]
    var messages: [Message]
    var isPinned: Bool
    var isMuted: Bool
    var draftText: String?

    var otherParticipant: User? {
        participants.first { $0.id != User.me.id }
    }

    var sortedMessages: [Message] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    var lastMessage: Message? { sortedMessages.last }

    var unreadCount: Int {
        messages.filter { !$0.isRead && !$0.isFromMe }.count
    }

    var displayTime: String {
        guard let last = lastMessage else { return "" }
        let diff = Date().timeIntervalSince(last.timestamp)
        if diff < 60 { return "now" }
        if diff < 3600 {
            let mins = Int(diff / 60)
            return "\(mins)m"
        }
        if diff < 86400 {
            let hrs = Int(diff / 3600)
            return "\(hrs)h"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: last.timestamp)
    }
}

// MARK: — Mock Data

extension Chat {
    static let mockChats: [Chat] = {
        let c1 = Chat(
            id: "c1",
            participants: [.me, .alex],
            messages: [
                .make("Hey! Have you tried Peak yet?",       from: User.alex.id, chatId: "c1", offset: -7200),
                .make("Just installed it, looks 🔥",          from: User.me.id,  chatId: "c1", offset: -7000),
                .make("Right? The B&W design is clean af",   from: User.alex.id, chatId: "c1", offset: -6800),
                .make("Feels like a different era of apps",  from: User.me.id,  chatId: "c1", offset: -6600),
                .make("Let me know when you add stories",    from: User.alex.id, chatId: "c1", offset: -300,  isRead: false),
            ],
            isPinned: true,
            isMuted: false,
            draftText: nil
        )
        let c2 = Chat(
            id: "c2",
            participants: [.me, .sam],
            messages: [
                .make("Are we meeting tomorrow?",            from: User.sam.id, chatId: "c2", offset: -86400),
                .make("Yep, 3pm works",                      from: User.me.id,  chatId: "c2", offset: -85000),
                .make("Perfect. I'll bring the laptop 💻",   from: User.sam.id, chatId: "c2", offset: -84000),
            ],
            isPinned: false,
            isMuted: false,
            draftText: nil
        )
        let c3 = Chat(
            id: "c3",
            participants: [.me, .nina],
            messages: [
                .make("The new dark theme update is 🤍",     from: User.nina.id, chatId: "c3", offset: -172800),
                .make("Sent you the design files",            from: User.nina.id, chatId: "c3", offset: -172000),
                .make("Got them, tysm!",                      from: User.me.id,   chatId: "c3", offset: -170000),
            ],
            isPinned: false,
            isMuted: true,
            draftText: nil
        )
        let c4 = Chat(
            id: "c4",
            participants: [.me, .jay],
            messages: [
                .make("sup",                                  from: User.jay.id, chatId: "c4", offset: -10),
                .make("not much, just building stuff",        from: User.me.id,  chatId: "c4", offset: -8, isRead: false),
            ],
            isPinned: false,
            isMuted: false,
            draftText: nil
        )
        return [c1, c2, c3, c4]
    }()
}
