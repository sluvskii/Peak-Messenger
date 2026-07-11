import Foundation

struct Chat: Identifiable, Hashable {
    let id: String
    let participants: [User]
    var messages: [Message]
    
    var otherParticipant: User? {
        participants.first { $0.id != User.mockMe.id }
    }
    
    var lastMessage: Message? {
        messages.sorted(by: { $0.timestamp < $1.timestamp }).last
    }
    
    // Mock data
    static let mockChats: [Chat] = [
        Chat(id: "c1", participants: [User.mockMe, User.mockFriend], messages: [
            Message(id: "m1", senderId: User.mockFriend.id, text: "Hey! How do you like Peak so far?", timestamp: Date().addingTimeInterval(-3600), isRead: true),
            Message(id: "m2", senderId: User.mockMe.id, text: "It's amazing. So minimalistic.", timestamp: Date().addingTimeInterval(-1800), isRead: true)
        ]),
        Chat(id: "c2", participants: [User.mockMe, User.mockFriend2], messages: [
            Message(id: "m3", senderId: User.mockFriend2.id, text: "Are we meeting tomorrow?", timestamp: Date().addingTimeInterval(-86400), isRead: true)
        ])
    ]
}
