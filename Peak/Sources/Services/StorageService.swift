import Foundation

// Firebase Storage integration will be added here once Firebase is configured.
final class StorageService {
    static let shared = StorageService()
    private init() {}

    func uploadMedia(_ data: Data, path: String) async throws -> URL {
        throw URLError(.unsupportedURL)
    }
}
