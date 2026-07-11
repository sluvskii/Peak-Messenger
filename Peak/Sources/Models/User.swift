import Foundation

struct User: Identifiable, Hashable, Codable {
    let id: UUID
    var username: String
    var bio: String
    var avatarUrl: String?
    var isOnline: Bool
    var lastSeen: Date?
    var phone: String?

    enum CodingKeys: String, CodingKey {
        case id, username, bio, phone
        case avatarUrl = "avatar_url"
        case isOnline = "is_online"
        case lastSeen = "last_seen"
    }

    var initials: String {
        let parts = username.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(username.prefix(2)).uppercased()
    }

    var lastSeenText: String {
        guard !isOnline else { return "в сети" }
        guard let lastSeen else { return "был(а) недавно" }
        let diff = Date().timeIntervalSince(lastSeen)
        if diff < 60 { return "был(а) только что" }
        if diff < 3600 { return "был(а) \(Int(diff / 60)) м назад" }
        if diff < 86400 { return "был(а) \(Int(diff / 3600)) ч назад" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "был(а) \(formatter.string(from: lastSeen))"
    }

    // MARK: — Mock Data
    static let me = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        username: "Вы",
        bio: "Peak early adopter 🖤",
        avatarUrl: nil,
        isOnline: true,
        lastSeen: nil,
        phone: "+1 000 000 00 00"
    )
    static let alex = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        username: "Alex Mercer",
        bio: "Less is more.",
        avatarUrl: nil,
        isOnline: true,
        lastSeen: nil,
        phone: "+1 234 567 89 00"
    )
    static let sam = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        username: "Sam Park",
        bio: "Design & coffee.",
        avatarUrl: nil,
        isOnline: false,
        lastSeen: Date().addingTimeInterval(-3600),
        phone: "+1 987 654 32 10"
    )
    static let nina = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        username: "Nina Volkov",
        bio: "Night mode forever.",
        avatarUrl: nil,
        isOnline: false,
        lastSeen: Date().addingTimeInterval(-86400),
        phone: "+7 999 123 45 67"
    )
    static let jay = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        username: "Jay Kim",
        bio: "",
        avatarUrl: nil,
        isOnline: true,
        lastSeen: nil,
        phone: "+82 10 1234 5678"
    )

    static let allContacts: [User] = [.alex, .sam, .nina, .jay]
}
