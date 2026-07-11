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
    let id: String
    let chatId: String
    let senderId: String
    let type: MessageType
    var text: String?
    var mediaUrl: String?
    var fileName: String?
    var fileSize: Int?          // bytes
    var duration: Double?       // seconds (for voice/video/circle)
    var reactions: [Reaction]
    let timestamp: Date
    var isRead: Bool
    var isEdited: Bool
    var replyToId: String?      // message id being replied to

    var isFromMe: Bool { senderId == User.me.id }

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
        from senderId: String,
        chatId: String,
        offset: TimeInterval,
        isRead: Bool = true
    ) -> Message {
        Message(
            id: UUID().uuidString,
            chatId: chatId,
            senderId: senderId,
            type: .text,
            text: text,
            mediaUrl: nil,
            fileName: nil,
            fileSize: nil,
            duration: nil,
            reactions: [],
            timestamp: Date().addingTimeInterval(offset),
            isRead: isRead,
            isEdited: false,
            replyToId: nil
        )
    }
}
