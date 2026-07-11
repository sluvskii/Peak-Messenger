import Foundation

struct User: Identifiable, Hashable {
    let id: String
    let username: String
    let avatarUrl: String?
    let isOnline: Bool
    
    // Mock user for testing
    static let mockMe = User(id: "1", username: "Peak User", avatarUrl: nil, isOnline: true)
    static let mockFriend = User(id: "2", username: "Alex", avatarUrl: nil, isOnline: true)
    static let mockFriend2 = User(id: "3", username: "Sam", avatarUrl: nil, isOnline: false)
}
