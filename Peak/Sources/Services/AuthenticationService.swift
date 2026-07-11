import Foundation

// Firebase Auth will be integrated here once GoogleService-Info.plist is added.
// For now this is a stub.

@MainActor
final class AuthenticationService {
    static let shared = AuthenticationService()
    private init() {}

    var currentUserId: String? { nil }

    func signIn(phone: String) async throws { }
    func signOut() throws { }
}
