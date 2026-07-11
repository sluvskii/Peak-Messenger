import Foundation

struct User: Identifiable, Hashable, Codable {
    let id: String
    var username: String
    var bio: String
    var avatarUrl: String?
    var isOnline: Bool
    var lastSeen: Date?
    var phone: String?

    var initials: String {
        let parts = username.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(username.prefix(2)).uppercased()
    }

    var lastSeenText: String {
        guard !isOnline else { return "online" }
        guard let lastSeen else { return "last seen recently" }
        let diff = Date().timeIntervalSince(lastSeen)
        if diff < 60 { return "last seen just now" }
        if diff < 3600 { return "last seen \(Int(diff / 60))m ago" }
        if diff < 86400 { return "last seen \(Int(diff / 3600))h ago" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "last seen \(formatter.string(from: lastSeen))"
    }

    // MARK: — Mock Data
    static let me = User(
        id: "me",
        username: "You",
        bio: "Peak early adopter 🖤",
        avatarUrl: nil,
        isOnline: true,
        lastSeen: nil,
        phone: "+1 000 000 00 00"
    )
    static let alex = User(
        id: "u2",
        username: "Alex Mercer",
        bio: "Less is more.",
        avatarUrl: nil,
        isOnline: true,
        lastSeen: nil,
        phone: "+1 234 567 89 00"
    )
    static let sam = User(
        id: "u3",
        username: "Sam Park",
        bio: "Design & coffee.",
        avatarUrl: nil,
        isOnline: false,
        lastSeen: Date().addingTimeInterval(-3600),
        phone: "+1 987 654 32 10"
    )
    static let nina = User(
        id: "u4",
        username: "Nina Volkov",
        bio: "Night mode forever.",
        avatarUrl: nil,
        isOnline: false,
        lastSeen: Date().addingTimeInterval(-86400),
        phone: "+7 999 123 45 67"
    )
    static let jay = User(
        id: "u5",
        username: "Jay Kim",
        bio: "",
        avatarUrl: nil,
        isOnline: true,
        lastSeen: nil,
        phone: "+82 10 1234 5678"
    )

    static let allContacts: [User] = [.alex, .sam, .nina, .jay]
}
