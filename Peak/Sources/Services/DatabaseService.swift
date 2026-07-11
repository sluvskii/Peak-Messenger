import Foundation

import Supabase

@MainActor
final class DatabaseService {
    static let shared = DatabaseService()
    private init() {}

    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: — Messages
    
    func fetchMessages(for chatId: UUID) async throws -> [Message] {
        try await client
            .from("messages")
            .select()
            .eq("chat_id", value: chatId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func sendMessage(_ message: Message) async throws {
        try await client
            .from("messages")
            .insert(message)
            .execute()
    }

    func listenForMessages(in chatId: UUID) async throws -> AsyncStream<Message> {
        let channel = client.channel("messages:chat_id=eq.\(chatId)")
        let stream = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "chat_id=eq.\(chatId)"
        )
        await channel.subscribe()
        
        return AsyncStream { continuation in
            Task {
                for await action in stream {
                    do {
                        let msg = try action.decode(as: Message.self)
                        continuation.yield(msg)
                    } catch {
                        print("Failed to decode message: \(error)")
                    }
                }
            }
        }
    }
}
