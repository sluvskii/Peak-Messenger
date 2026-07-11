import Foundation

// Firestore integration will be added here once Firebase is configured.
final class DatabaseService {
    static let shared = DatabaseService()
    private init() {}

    func sendMessage(_ text: String, to chatId: String) async throws { }
    func fetchMessages(for chatId: String) async throws -> [Message] { [] }
}
