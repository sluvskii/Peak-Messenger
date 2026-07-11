import Foundation

import Supabase

@MainActor
final class DatabaseService {
    static let shared = DatabaseService()
    private init() {}

    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: — Users

    func fetchAllUsers() async throws -> [User] {
        try await client
            .from("users")
            .select()
            .execute()
            .value
    }

    // MARK: — Chats

    func getOrCreateChat(with otherUserId: UUID) async throws -> Chat {
        guard let myId = try await AuthenticationService.shared.currentUserId else {
            throw URLError(.userAuthenticationRequired)
        }
        
        // Check if chat exists
        // A simple query: find chat where we both are participants.
        // We can call an RPC, but doing it in swift via select:
        struct ParticipantResult: Decodable {
            let chat_id: UUID
        }
        // This is a naive approach, best done via Postgres RPC, but let's try direct for MVP:
        // Or simply create a new chat every time for prototyping, but let's do a simple RPC or just create it.
        // To avoid complexity, let's just create a chat and add both.
        
        // Actually, we can fetch all our chats and see if otherUser is in it.
        let myChatsResponse: [ParticipantResult] = try await client
            .from("chat_participants")
            .select("chat_id")
            .eq("user_id", value: myId)
            .execute()
            .value
            
        let myChatIds = myChatsResponse.map { $0.chat_id }
        
        if !myChatIds.isEmpty {
            let sharedChats: [ParticipantResult] = try await client
                .from("chat_participants")
                .select("chat_id")
                .eq("user_id", value: otherUserId)
                .in("chat_id", values: myChatIds)
                .execute()
                .value
                
            if let existingChatId = sharedChats.first?.chat_id {
                let otherUser: User = try await client.from("users").select().eq("id", value: otherUserId).single().execute().value
                let me: User = try await client.from("users").select().eq("id", value: myId).single().execute().value
                
                return Chat(id: existingChatId, participants: [me, otherUser], messages: [], isPinned: false, isMuted: false, draftText: nil)
            }
        }
        
        // Create new chat
        struct ChatInsert: Encodable { }
        struct ChatResult: Decodable { let id: UUID }
        let newChat: ChatResult = try await client.from("chats").insert(ChatInsert()).select("id").single().execute().value
        
        // Insert participants
        struct ParticipantInsert: Encodable {
            let chat_id: UUID
            let user_id: UUID
        }
        try await client.from("chat_participants").insert([
            ParticipantInsert(chat_id: newChat.id, user_id: myId),
            ParticipantInsert(chat_id: newChat.id, user_id: otherUserId)
        ]).execute()
        
        let otherUser: User = try await client.from("users").select().eq("id", value: otherUserId).single().execute().value
        let me: User = try await client.from("users").select().eq("id", value: myId).single().execute().value
        
        return Chat(id: newChat.id, participants: [me, otherUser], messages: [], isPinned: false, isMuted: false, draftText: nil)
    }

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
            AnyAction.self,
            schema: "public",
            table: "messages",
            filter: "chat_id=eq.\(chatId)"
        )
        Task { try? await channel.subscribeWithError() }
        
        return AsyncStream { continuation in
            Task {
                for await action in stream {
                    do {
                        let data = try JSONEncoder().encode(action.record)
                        
                        let decoder = JSONDecoder()
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        decoder.dateDecodingStrategy = .custom({ decoder in
                            let container = try decoder.singleValueContainer()
                            let string = try container.decode(String.self)
                            if let date = formatter.date(from: string) { return date }
                            formatter.formatOptions = [.withInternetDateTime]
                            if let date = formatter.date(from: string) { return date }
                            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
                        })
                        
                        let msg = try decoder.decode(Message.self, from: data)
                        continuation.yield(msg)
                    } catch {
                        print("Failed to decode message: \(error)")
                    }
                }
            }
        }
    }
}
