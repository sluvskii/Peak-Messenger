import Foundation

class DatabaseService {
    static let shared = DatabaseService()
    
    private init() {}
    
    func sendMessage(_ text: String, to userId: String) {
        // Stub for Firestore
    }
    
    func fetchMessages(for chatId: String) {
        // Stub for Firestore
    }
}
