import Foundation
import Supabase

final class SupabaseService: @unchecked Sendable {
    static let shared = SupabaseService()

    let config: AppConfig
    let client: SupabaseClient?

    var isConfigured: Bool {
        config.isSupabaseConfigured && client != nil
    }

    init(config: AppConfig = .current) {
        self.config = config
        if let url = config.supabaseURL, config.isSupabaseConfigured {
            client = SupabaseClient(supabaseURL: url, supabaseKey: config.supabaseAnonKey)
        } else {
            client = nil
        }
    }
}

extension SupabaseService: AuthServicing {
    func restoredSessionUser() async throws -> AuthenticatedUser? {
        guard let client else {
            throw AuthServiceError.configurationMissing
        }

        do {
            let session = try await client.auth.session
            return AuthenticatedUser(user: session.user)
        } catch let error as AuthError {
            if case .sessionMissing = error {
                return nil
            }
            if isExpiredSession(error) {
                throw AuthServiceError.sessionExpired
            }
            throw AuthServiceError.backend(error.message)
        } catch {
            throw AuthServiceError.backend(error.localizedDescription)
        }
    }

    func signIn(email: String, password: String) async throws -> AuthenticatedUser {
        guard let client else {
            throw AuthServiceError.configurationMissing
        }

        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return AuthenticatedUser(user: session.user)
        } catch let error as AuthError {
            throw mapAuthError(error)
        } catch {
            throw AuthServiceError.backend(error.localizedDescription)
        }
    }

    func bootstrap(user: AuthenticatedUser) async throws -> AuthBootstrapResult {
        guard let client else {
            throw AuthServiceError.configurationMissing
        }

        let profile: ProfileRow?
        do {
            profile = try await client
                .from("profiles")
                .select("id, email, full_name, display_name, short_name, role, avatar_url, department, active, is_active")
                .eq("id", value: user.id)
                .maybeSingle()
                .execute()
                .value
        } catch {
            throw AuthServiceError.backend(error.localizedDescription)
        }

        guard let profile else {
            try? await signOut()
            throw AuthServiceError.forbidden
        }

        guard (profile.isActive ?? profile.active ?? true) else {
            try? await signOut()
            throw AuthServiceError.forbidden
        }

        let override = try await loadPermissionOverride(client: client, profileID: user.id)
        return AuthBootstrapResult(
            profile: profile.summary(fallback: AuthProfileSummary.fallback(for: user)),
            permissionOverride: override
        )
    }

    func signOut() async throws {
        guard let client else {
            return
        }
        try await client.auth.signOut()
    }

    func requestPasswordReset(email: String) async throws {
        throw AuthServiceError.passwordResetUnavailable
    }

    private func loadPermissionOverride(client: SupabaseClient, profileID: UUID) async throws -> UserPermissionOverride {
        do {
            let row: PermissionOverrideRow? = try await client
                .from("user_permission_overrides")
                .select("""
                    access_mode,
                    dashboard_view,
                    calendar_view,
                    calendar_edit,
                    tasks_view,
                    tasks_edit,
                    content_plan_view,
                    content_plan_edit_content,
                    content_plan_assign_editor,
                    users_manage,
                    profile_edit_self
                """)
                .eq("profile_id", value: profileID)
                .maybeSingle()
                .execute()
                .value
            return row?.override ?? .roleDefault
        } catch let error as PostgrestError {
            if isMissingOverrideTable(error) {
                return .roleDefault
            }
            throw AuthServiceError.backend(error.message)
        } catch {
            throw AuthServiceError.backend(error.localizedDescription)
        }
    }

    private func mapAuthError(_ error: AuthError) -> AuthServiceError {
        let message = error.message.lowercased()
        let code = error.errorCode.rawValue

        if message.contains("invalid login credentials") || code == "invalid_credentials" {
            return .invalidCredentials
        }
        if message.contains("email not confirmed") {
            return .emailNotConfirmed
        }
        if message.contains("rate limit") || code == "over_email_send_rate_limit" || code == "over_request_rate_limit" {
            return .rateLimited
        }
        if isExpiredSession(error) {
            return .sessionExpired
        }
        return .backend(error.message)
    }

    private func isExpiredSession(_ error: AuthError) -> Bool {
        let code = error.errorCode.rawValue
        let message = error.message.lowercased()
        return code == "session_expired" ||
            code == "session_not_found" ||
            code == "refresh_token_not_found" ||
            code == "refresh_token_already_used" ||
            message.contains("refresh token") ||
            message.contains("session expired")
    }

    private func isMissingOverrideTable(_ error: PostgrestError) -> Bool {
        let message = error.message.lowercased()
        return error.code == "42P01" ||
            error.code == "PGRST205" ||
            message.contains("user_permission_overrides") ||
            message.contains("could not find the table")
    }
}

private struct ProfileRow: Decodable {
    var id: UUID
    var email: String?
    var fullName: String?
    var displayName: String?
    var shortName: String?
    var role: String?
    var avatarURL: String?
    var department: String?
    var active: Bool?
    var isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case displayName = "display_name"
        case shortName = "short_name"
        case role
        case avatarURL = "avatar_url"
        case department
        case active
        case isActive = "is_active"
    }

    func summary(fallback: AuthProfileSummary) -> AuthProfileSummary {
        let resolvedDisplayName = displayName.nonEmpty ?? shortName.nonEmpty ?? fullName.nonEmpty ?? fallback.displayName
        return AuthProfileSummary(
            id: id,
            email: email.nonEmpty ?? fallback.email,
            fullName: fullName.nonEmpty ?? resolvedDisplayName,
            displayName: resolvedDisplayName,
            avatarURL: avatarURL.nonEmpty.flatMap(URL.init(string:)) ?? fallback.avatarURL,
            department: department.nonEmpty ?? "Team Marketing",
            role: CreativeHubRole(rawValue: role),
            rawRole: role
        )
    }
}

private struct PermissionOverrideRow: Decodable {
    var accessMode: String?
    var dashboardView: Bool?
    var calendarView: Bool?
    var calendarEdit: Bool?
    var tasksView: Bool?
    var tasksEdit: Bool?
    var contentPlanView: Bool?
    var contentPlanEditContent: Bool?
    var contentPlanAssignEditor: Bool?
    var usersManage: Bool?
    var profileEditSelf: Bool?

    enum CodingKeys: String, CodingKey {
        case accessMode = "access_mode"
        case dashboardView = "dashboard_view"
        case calendarView = "calendar_view"
        case calendarEdit = "calendar_edit"
        case tasksView = "tasks_view"
        case tasksEdit = "tasks_edit"
        case contentPlanView = "content_plan_view"
        case contentPlanEditContent = "content_plan_edit_content"
        case contentPlanAssignEditor = "content_plan_assign_editor"
        case usersManage = "users_manage"
        case profileEditSelf = "profile_edit_self"
    }

    var override: UserPermissionOverride {
        UserPermissionOverride(
            accessMode: PermissionAccessMode(rawValue: accessMode),
            flags: [
                "dashboard_view": dashboardView,
                "calendar_view": calendarView,
                "calendar_edit": calendarEdit,
                "tasks_view": tasksView,
                "tasks_edit": tasksEdit,
                "content_plan_view": contentPlanView,
                "content_plan_edit_content": contentPlanEditContent,
                "content_plan_assign_editor": contentPlanAssignEditor,
                "users_manage": usersManage,
                "profile_edit_self": profileEditSelf
            ]
        )
    }
}

private extension AuthenticatedUser {
    init(user: User) {
        id = user.id
        email = user.email
        metadata = user.userMetadata.compactMapValues { $0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

private extension AuthProfileSummary {
    static func fallback(for user: AuthenticatedUser) -> AuthProfileSummary {
        let fallbackName = user.metadata["full_name"].nonEmpty ??
            user.metadata["name"].nonEmpty ??
            user.email?.split(separator: "@").first.map(String.init).nonEmpty ??
            "Nhân sự"

        return AuthProfileSummary(
            id: user.id,
            email: user.email ?? "",
            fullName: fallbackName,
            displayName: fallbackName,
            avatarURL: user.metadata["avatar_url"].nonEmpty.flatMap(URL.init(string:)),
            department: "Team Marketing",
            role: .editor,
            rawRole: nil
        )
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
