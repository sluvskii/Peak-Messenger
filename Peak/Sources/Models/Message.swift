import Foundation

struct Message: Identifiable, Hashable {
    let id: String
    let senderId: String
    let text: String
    let timestamp: Date
    let isRead: Bool
    
    var isFromMe: Bool {
        return senderId == User.mockMe.id
    }
}
