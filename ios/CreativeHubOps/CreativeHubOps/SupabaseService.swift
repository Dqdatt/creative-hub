import Foundation
import Supabase

struct AuthSessionSnapshot: Equatable, Identifiable {
    let id: UUID
    let email: String?
    let displayName: String?
}

protocol SupabaseAuthServicing: Sendable {
    func restoreSession() async throws -> AuthSessionSnapshot?
    func signIn(email: String, password: String) async throws -> AuthSessionSnapshot
    func signOut() async throws
    func updatePassword(email: String, currentPassword: String, newPassword: String) async throws
}

final class SupabaseService: SupabaseAuthServicing {
    private let client: SupabaseClient

    init(config: AppConfig) {
        client = SupabaseClient(supabaseURL: config.supabaseURL, supabaseKey: config.supabaseAnonKey)
    }

    convenience init() throws {
        try self.init(config: AppConfig.current())
    }

    func restoreSession() async throws -> AuthSessionSnapshot? {
        do {
            let session = try await client.auth.session
            return Self.snapshot(from: session)
        } catch {
            return nil
        }
    }

    func signIn(email: String, password: String) async throws -> AuthSessionSnapshot {
        let session = try await client.auth.signIn(email: email, password: password)
        return Self.snapshot(from: session)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func updatePassword(email: String, currentPassword: String, newPassword: String) async throws {
        _ = try await client.auth.signIn(email: email, password: currentPassword)
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    private static func snapshot(from session: Session) -> AuthSessionSnapshot {
        AuthSessionSnapshot(
            id: session.user.id,
            email: session.user.email,
            displayName: nil
        )
    }
}
