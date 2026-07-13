import Foundation

// MARK: — CacheService

/// A simple file-based JSON cache for offline-first support.
final class CacheService: @unchecked Sendable {
    static let shared = CacheService()
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private let chatsURL: URL
    private let userURL: URL
    private let contactsURL: URL
    private let reactionsURL: URL
    
    private init() {
        let documentsPath = URL.documentsDirectory
        chatsURL = documentsPath.appendingPathComponent("chats_cache.json")
        userURL = documentsPath.appendingPathComponent("user_cache.json")
        contactsURL = documentsPath.appendingPathComponent("contacts_cache.json")
        reactionsURL = documentsPath.appendingPathComponent("reactions_cache.json")
    }
    
    // MARK: - Save
    
    func saveChats(_ chats: [Chat]) {
        if let data = try? encoder.encode(chats) {
            try? data.write(to: chatsURL, options: .atomic)
        }
    }
    
    func saveUser(_ user: User) {
        if let data = try? encoder.encode(user) {
            try? data.write(to: userURL, options: .atomic)
        }
    }
    
    func saveContacts(_ contacts: [User]) {
        if let data = try? encoder.encode(contacts) {
            try? data.write(to: contactsURL, options: .atomic)
        }
    }
    
    func saveReactions(_ reactions: [UUID: [Reaction]]) {
        if let data = try? encoder.encode(reactions) {
            try? data.write(to: reactionsURL, options: .atomic)
        }
    }
    
    // MARK: - Load
    
    func loadChats() -> [Chat]? {
        guard let data = try? Data(contentsOf: chatsURL) else { return nil }
        return try? decoder.decode([Chat].self, from: data)
    }
    
    func loadUser() -> User? {
        guard let data = try? Data(contentsOf: userURL) else { return nil }
        return try? decoder.decode(User.self, from: data)
    }
    
    func loadContacts() -> [User]? {
        guard let data = try? Data(contentsOf: contactsURL) else { return nil }
        return try? decoder.decode([User].self, from: data)
    }
    
    func loadReactions() -> [UUID: [Reaction]]? {
        guard let data = try? Data(contentsOf: reactionsURL) else { return nil }
        return try? decoder.decode([UUID: [Reaction]].self, from: data)
    }
    
    // MARK: - Clear
    
    func clearAll() {
        try? FileManager.default.removeItem(at: chatsURL)
        try? FileManager.default.removeItem(at: userURL)
        try? FileManager.default.removeItem(at: contactsURL)
        try? FileManager.default.removeItem(at: reactionsURL)
    }
}
