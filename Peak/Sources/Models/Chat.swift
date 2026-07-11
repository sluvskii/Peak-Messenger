import Foundation

// MARK: — Chat

struct Chat: Identifiable, Hashable, Codable {
    let id: UUID
    let participants: [User]
    var messages: [Message]
    var isPinned: Bool
    var isMuted: Bool
    var draftText: String?

    func otherParticipant(myId: UUID?) -> User? {
        guard let myId = myId else {
            return participants.first { $0.id != User.me.id }
        }
        return participants.first { $0.id != myId } ?? participants.first
    }

    var sortedMessages: [Message] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    var lastMessage: Message? { sortedMessages.last }

    func unreadCount(myId: UUID?) -> Int {
        messages.filter { !$0.isRead && !$0.isFromMe(myId: myId) }.count
    }

    var displayTime: String {
        guard let last = lastMessage else { return "" }
        let diff = Date().timeIntervalSince(last.timestamp)
        if diff < 60 { return "сейчас" }
        if diff < 3600 {
            let mins = Int(diff / 60)
            return "\(mins)м"
        }
        if diff < 86400 {
            let hrs = Int(diff / 3600)
            return "\(hrs)ч"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: last.timestamp)
    }
}

// MARK: — Mock Data

extension Chat {
    static let mockChats: [Chat] = {
        let c1 = Chat(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            participants: [.me, .alex],
            messages: [
                .make("Hey! Have you tried Peak yet?",       from: User.alex.id, chatId: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, offset: -7200),
                .make("Just installed it, looks 🔥",          from: User.me.id,  chatId: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, offset: -7000),
                .make("Right? The B&W design is clean af",   from: User.alex.id, chatId: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, offset: -6800),
                .make("Feels like a different era of apps",  from: User.me.id,  chatId: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, offset: -6600),
                .make("Let me know when you add stories",    from: User.alex.id, chatId: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, offset: -300,  isRead: false),
            ],
            isPinned: true,
            isMuted: false,
            draftText: nil
        )
        let c2 = Chat(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            participants: [.me, .sam],
            messages: [
                .make("Are we meeting tomorrow?",            from: User.sam.id, chatId: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, offset: -86400),
                .make("Yep, 3pm works",                      from: User.me.id,  chatId: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, offset: -85000),
                .make("Perfect. I'll bring the laptop 💻",   from: User.sam.id, chatId: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, offset: -84000),
            ],
            isPinned: false,
            isMuted: false,
            draftText: nil
        )
        let c3 = Chat(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
            participants: [.me, .nina],
            messages: [
                .make("The new dark theme update is 🤍",     from: User.nina.id, chatId: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, offset: -172800),
                .make("Sent you the design files",            from: User.nina.id, chatId: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, offset: -172000),
                .make("Got them, tysm!",                      from: User.me.id,   chatId: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, offset: -170000),
            ],
            isPinned: false,
            isMuted: true,
            draftText: nil
        )
        let c4 = Chat(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
            participants: [.me, .jay],
            messages: [
                .make("sup",                                  from: User.jay.id, chatId: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!, offset: -10),
                .make("not much, just building stuff",        from: User.me.id,  chatId: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!, offset: -8, isRead: false),
            ],
            isPinned: false,
            isMuted: false,
            draftText: nil
        )
        return [c1, c2, c3, c4]
    }()
}
