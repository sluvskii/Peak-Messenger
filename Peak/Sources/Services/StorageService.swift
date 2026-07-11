import Foundation
import Supabase

@MainActor
final class StorageService {
    static let shared = StorageService()
    private init() {}

    private var client: SupabaseClient { SupabaseManager.shared.client }

    func uploadMedia(_ data: Data, bucket: String, path: String, contentType: String) async throws -> URL {
        // Upload the file
        try await client.storage
            .from(bucket)
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: contentType)
            )

        // Generate public URL
        let url = try client.storage.from(bucket).getPublicURL(path: path)
        return url
    }
}
