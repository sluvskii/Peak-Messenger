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
    
    func updateAvatarUrl(_ url: String) async throws {
        guard let myId = try await AuthenticationService.shared.currentUserId else { return }
        struct UpdateAvatar: Encodable { let avatar_url: String }
        try await client
            .from("users")
            .update(UpdateAvatar(avatar_url: url))
            .eq("id", value: myId)
            .execute()
    }
    
    func updateUsername(_ name: String) async throws {
        guard let myId = try await AuthenticationService.shared.currentUserId else { return }
        struct UpdateName: Encodable { let username: String }
        try await client
            .from("users")
            .update(UpdateName(username: name))
            .eq("id", value: myId)
            .execute()
    }
    
    func updatePresence(isOnline: Bool) async throws {
        guard let myId = try await AuthenticationService.shared.currentUserId else { return }
        struct UpdatePresenceModel: Encodable { 
            let is_online: Bool
            let last_seen: String // ISO8601 string
        }
        let now = ISO8601DateFormatter().string(from: Date())
        try await client
            .from("users")
            .update(UpdatePresenceModel(is_online: isOnline, last_seen: now))
            .eq("id", value: myId)
            .execute()
    }

    func listenForUserUpdates() async throws -> AsyncStream<User> {
        let channel = client.channel("users:all")
        let stream = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "users"
        )
        Task { try? await channel.subscribeWithError() }
        
        return AsyncStream { continuation in
            Task {
                for await action in stream {
                    do {
                        let data = try JSONEncoder().encode(action.record)
                        let user = try JSONDecoder().decode(User.self, from: data)
                        continuation.yield(user)
                    } catch {
                        print("Failed to decode user update: \(error)")
                    }
                }
            }
        }
    }

    // MARK: — Chats

    func fetchMyChats() async throws -> [Chat] {
        guard let myId = try await AuthenticationService.shared.currentUserId else { return [] }
        
        struct ParticipantResult: Decodable { let chat_id: UUID }
        let myChatsResponse: [ParticipantResult] = try await client
            .from("chat_participants")
            .select("chat_id")
            .eq("user_id", value: myId)
            .execute()
            .value
            
        let myChatIds = myChatsResponse.map { $0.chat_id }
        guard !myChatIds.isEmpty else { return [] }
        
        struct ParticipantUser: Decodable {
            let chat_id: UUID
            let user_id: UUID
            let is_pinned: Bool
            let is_muted: Bool
        }
        
        let participants: [ParticipantUser] = try await client
            .from("chat_participants")
            .select("chat_id, user_id, is_pinned, is_muted")
            .in("chat_id", values: myChatIds)
            .execute()
            .value
            
        let userIds = Array(Set(participants.map { $0.user_id }))
        let users: [User] = try await client
            .from("users")
            .select()
            .in("id", values: userIds)
            .execute()
            .value
            
        let usersDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        
        var chats: [Chat] = []
        for chatId in myChatIds {
            let chatParticipants = participants.filter { $0.chat_id == chatId }
            let chatUsers = chatParticipants.compactMap { usersDict[$0.user_id] }
            
            let isPinned = chatParticipants.first(where: { $0.user_id == myId })?.is_pinned ?? false
            let isMuted = chatParticipants.first(where: { $0.user_id == myId })?.is_muted ?? false
            
            chats.append(Chat(id: chatId, participants: chatUsers, messages: [], isPinned: isPinned, isMuted: isMuted, draftText: nil))
        }
        
        let allMessages: [Message] = try await client
            .from("messages")
            .select()
            .in("chat_id", values: myChatIds)
            .order("created_at", ascending: true)
            .execute()
            .value
            
        let messagesByChat = Dictionary(grouping: allMessages, by: { $0.chatId })
        for i in 0..<chats.count {
            chats[i].messages = messagesByChat[chats[i].id] ?? []
        }
        
        return chats
    }

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
            struct ParticipantUser: Decodable {
                let chat_id: UUID
                let user_id: UUID
            }
            let allParticipants: [ParticipantUser] = try await client
                .from("chat_participants")
                .select("chat_id, user_id")
                .in("chat_id", values: myChatIds)
                .execute()
                .value
                
            var participantsByChat: [UUID: [UUID]] = [:]
            for p in allParticipants {
                participantsByChat[p.chat_id, default: []].append(p.user_id)
            }
            
            var existingChatId: UUID?
            for (chatId, userIds) in participantsByChat {
                if myId == otherUserId {
                    if userIds.count == 1 && userIds.contains(myId) {
                        existingChatId = chatId
                        break
                    }
                } else {
                    if userIds.count == 2 && userIds.contains(myId) && userIds.contains(otherUserId) {
                        existingChatId = chatId
                        break
                    }
                }
            }
                
            if let existingChatId = existingChatId {
                let otherUser: User = try await client.from("users").select().eq("id", value: otherUserId).single().execute().value
                let me: User = try await client.from("users").select().eq("id", value: myId).single().execute().value
                
                // If it's a self chat, participants should just be [me] or [me, me]?
                // Let's keep it [me, otherUser] even if they are the same so UI logic doesn't break,
                // but actually participants array in Chat could just have unique users or we just return [me, otherUser]
                return Chat(id: existingChatId, participants: [me, otherUser], messages: [], isPinned: false, isMuted: false, draftText: nil)
            }
        }
        
        // Create new chat
        let newChatId = UUID()
        struct ChatInsert: Encodable { let id: UUID }
        try await client.from("chats").insert(ChatInsert(id: newChatId)).execute()
        
        // Insert participants
        struct ParticipantInsert: Encodable {
            let chat_id: UUID
            let user_id: UUID
        }
        
        var participantsToInsert: [ParticipantInsert] = [
            ParticipantInsert(chat_id: newChatId, user_id: myId)
        ]
        if myId != otherUserId {
            participantsToInsert.append(ParticipantInsert(chat_id: newChatId, user_id: otherUserId))
        }
        
        try await client.from("chat_participants").insert(participantsToInsert).execute()
        
        let otherUser: User = try await client.from("users").select().eq("id", value: otherUserId).single().execute().value
        let me: User = try await client.from("users").select().eq("id", value: myId).single().execute().value
        
        return Chat(id: newChatId, participants: [me, otherUser], messages: [], isPinned: false, isMuted: false, draftText: nil)
    }

    // MARK: — Messages
    
    func deleteChatParticipant(chatId: UUID) async throws {
        guard let myId = try await AuthenticationService.shared.currentUserId else { return }
        try await client
            .from("chat_participants")
            .delete()
            .eq("chat_id", value: chatId)
            .eq("user_id", value: myId)
            .execute()
    }
    
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
    
    func updateMessage(_ message: Message) async throws {
        struct UpdateContent: Encodable {
            let text: String?
            let type: MessageType
            let is_edited: Bool
        }
        
        try await client
            .from("messages")
            .update(UpdateContent(text: message.text, type: message.type, is_edited: message.isEdited))
            .eq("id", value: message.id)
            .execute()
    }

    func markMessagesAsRead(in chatId: UUID, myId: UUID) async throws {
        struct UpdateRead: Encodable { let is_read: Bool }
        try await client
            .from("messages")
            .update(UpdateRead(is_read: true))
            .eq("chat_id", value: chatId)
            .neq("sender_id", value: myId)
            .eq("is_read", value: false)
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
        Task { try? await channel.subscribeWithError() }
        
        return AsyncStream { continuation in
            Task {
                for await action in stream {
                    do {
                        let data = try JSONEncoder().encode(action.record)
                        
                        let decoder = JSONDecoder()
                        let msg = try decoder.decode(Message.self, from: data)
                        continuation.yield(msg)
                    } catch {
                        print("Failed to decode message: \(error)")
                    }
                }
            }
        }
    }
    func listenForAllMessages() async throws -> AsyncStream<Message> {
        let channel = client.channel("messages:all")
        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "messages"
        )
        Task { try? await channel.subscribeWithError() }
        
        return AsyncStream { continuation in
            Task {
                for await action in stream {
                    do {
                        let record: [String: AnyJSON]
                        switch action {
                        case .insert(let insertAction): record = insertAction.record
                        case .update(let updateAction): record = updateAction.record
                        case .delete: continue
                        }
                        
                        let data = try JSONEncoder().encode(record)
                        let decoder = JSONDecoder()
                        let msg = try decoder.decode(Message.self, from: data)
                        continuation.yield(msg)
                    } catch {
                        print("Failed to decode global message: \(error)")
                    }
                }
            }
        }
    }
}
