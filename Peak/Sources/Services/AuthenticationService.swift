import Foundation

import Supabase

@MainActor
final class AuthenticationService {
    static let shared = AuthenticationService()
    private init() {}
    
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Returns an async stream of auth state changes (e.g. signedIn, signedOut)
    var authStateChanges: AsyncStream<(AuthChangeEvent, Session?)> {
        client.auth.authStateChanges
    }

    /// Sign in with email for simplicity in MVP, or we can use OTP
    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }
    
    func signUp(email: String, password: String, username: String) async throws {
        let response = try await client.auth.signUp(
            email: email, 
            password: password,
            data: ["username": .string(username)]
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
