import Foundation

// MARK: — Message Type

enum MessageType: String, Codable, Hashable {
    case text
    case image
    case video
    case circle    // video message (like Telegram circles)
    case file
    case voice
    case deleted
}

// MARK: — Reaction

struct Reaction: Identifiable, Hashable, Codable {
    let id: String
    let emoji: String
    let senderId: String
}

// MARK: — Message

struct Message: Identifiable, Hashable, Codable {
    let id: UUID
    let chatId: UUID
    let senderId: UUID
    var type: MessageType
    var text: String?
    var mediaUrl: String?
    var fileName: String?
    var fileSize: Int?          // bytes
    var duration: Double?       // seconds (for voice/video/circle)
    // var reactions: [Reaction] // We will ignore reactions in DB for now to keep it simple, or handle later
    @RobustDate var timestamp: Date
    var isRead: Bool
    var isEdited: Bool
    var replyToId: UUID?      // message id being replied to

    enum CodingKeys: String, CodingKey {
        case id, type, text
        case chatId = "chat_id"
        case senderId = "sender_id"
        case mediaUrl = "media_url"
        case fileName = "file_name"
        case fileSize = "file_size"
        case duration
        case timestamp = "created_at"
        case isRead = "is_read"
        case isEdited = "is_edited"
        case replyToId = "reply_to_id"
    }
    func isFromMe(myId: UUID?) -> Bool {
        guard let myId = myId else { return senderId == User.me.id }
        return senderId == myId
    }
    var displayText: String {
        switch type {
        case .text:    return text ?? ""
        case .image:   return "🖼 Фото"
        case .video:   return "🎥 Видео"
        case .circle:  return "⭕ Видеосообщение"
        case .file:    return "📎 \(fileName ?? "Файл")"
        case .voice:   return "🎤 Голосовое"
        case .deleted: return "Сообщение удалено"
        }
    }
}

// MARK: — Mock Data

extension Message {
    static func make(
        _ text: String,
        from senderId: UUID,
        chatId: UUID,
        offset: TimeInterval,
        isRead: Bool = true
    ) -> Message {
        Message(
            id: UUID(),
            chatId: chatId,
            senderId: senderId,
            type: .text,
            text: text,
            mediaUrl: nil,
            fileName: nil,
            fileSize: nil,
            duration: nil,
            timestamp: Date().addingTimeInterval(offset),
            isRead: isRead,
            isEdited: false,
            replyToId: nil
        )
    }
}
