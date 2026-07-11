import Foundation

class StorageService {
    static let shared = StorageService()
    
    private init() {}
    
    func uploadMedia(_ data: Data, path: String) {
        // Stub for Firebase Storage
    }
}
