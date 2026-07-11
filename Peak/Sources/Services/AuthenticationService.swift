import Foundation

import Supabase

@MainActor
final class AuthenticationService {
    static let shared = AuthenticationService()
    private init() {}
    
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Returns the current authenticated user's ID
    var currentUserId: UUID? {
        get async {
            try? await client.auth.session.user.id
        }
    }
    var authStateChanges: AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        client.auth.authStateChanges
    }

    /// Sign in with email for simplicity in MVP, or we can use OTP
    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }
    
    func signUp(email: String, password: String, username: String) async throws {
        _ = try await client.auth.signUp(
            email: email, 
            password: password,
            data: ["username": .string(username)]
        )
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
        } catch {
            print("Server sign out failed: \(error), forcing local sign out")
            try? await client.auth.signOut(scope: .local)
        }
    }
}
