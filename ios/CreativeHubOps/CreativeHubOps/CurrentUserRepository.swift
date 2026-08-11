import Foundation
import Supabase

protocol CurrentUserRepositoryServing: Sendable {
    func fetchCurrentUser(session: AuthSessionSnapshot) async throws -> CurrentUserProfile
    func updateProfile(userId: UUID, data: ProfileFormData) async throws
    func uploadAvatar(userId: UUID, imageData: Data, fileName: String) async throws -> String
    func updateAvatar(userId: UUID, avatarURL: String) async throws
}

final class CurrentUserRepository: CurrentUserRepositoryServing {
    private let client: SupabaseClient

    init(config: AppConfig) {
        client = SupabaseClient(supabaseURL: config.supabaseURL, supabaseKey: config.supabaseAnonKey)
    }

    convenience init() throws {
        try self.init(config: AppConfig.current())
    }

    func fetchCurrentUser(session: AuthSessionSnapshot) async throws -> CurrentUserProfile {
        let profile: ProfileRow? = try await client
            .from("profiles")
            .select("id,email,full_name,display_name,short_name,phone,role,department,avatar_url,editor_code,crew_key,is_editor_member,active,is_active")
            .eq("id", value: session.id.uuidString)
            .maybeSingle()
            .execute()
            .value

        guard let profile else {
            throw AppError.notFound("Tài khoản không còn hoạt động. Vui lòng đăng nhập lại.")
        }

        guard (profile.isActive ?? profile.active ?? true) == true else {
            throw AppError.auth("Tài khoản đã bị tạm khóa. Vui lòng liên hệ quản trị viên.")
        }

        let override = await fetchPermissionOverride(profileId: session.id)
        return profile.domain(session: session, override: override)
    }

    func updateProfile(userId: UUID, data: ProfileFormData) async throws {
        let displayName = data.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayName.isEmpty else {
            throw AppError.validation("Vui lòng nhập tên hiển thị.")
        }

        let payload = ProfileUpdatePayload(
            fullName: data.fullName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? displayName,
            displayName: displayName,
            shortName: displayName,
            phone: data.phone.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
            department: data.department.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "Team Marketing"
        )

        try await client
            .from("profiles")
            .update(payload)
            .eq("id", value: userId.uuidString)
            .execute()
    }

    func uploadAvatar(userId: UUID, imageData: Data, fileName: String) async throws -> String {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let filePath = AvatarImageProcessor.storagePath(
            userId: userId,
            fileName: fileName,
            timestampMilliseconds: timestamp
        )

        do {
            try await client.storage
                .from("avatars")
                .upload(
                    filePath,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: AvatarImageProcessor.outputContentType,
                        upsert: true
                    )
                )
        } catch {
            throw mapStorageError(error)
        }

        do {
            return try client.storage.from("avatars").getPublicURL(path: filePath).absoluteString
        } catch {
            throw AppError.backend("Không thể lấy đường dẫn ảnh đại diện.")
        }
    }

    func updateAvatar(userId: UUID, avatarURL: String) async throws {
        let cleanURL = avatarURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanURL.isEmpty else {
            throw AppError.validation("Không tìm thấy ảnh đại diện đã tải lên.")
        }

        try await client
            .from("profiles")
            .update(ProfileAvatarUpdatePayload(avatarURL: cleanURL))
            .eq("id", value: userId.uuidString)
            .execute()
    }

    private func fetchPermissionOverride(profileId: UUID) async -> UserPermissionOverride {
        do {
            let row: PermissionOverrideRow? = try await client
                .from("user_permission_overrides")
                .select("access_mode,dashboard_view,calendar_view,calendar_edit,tasks_view,tasks_edit,content_plan_view,content_plan_edit_content,content_plan_assign_editor,users_manage,profile_edit_self")
                .eq("profile_id", value: profileId.uuidString)
                .maybeSingle()
                .execute()
                .value

            return row?.domain ?? .roleDefault
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("user_permission_overrides") ||
                message.contains("could not find the table") ||
                message.contains("pgrst205") ||
                message.contains("42p01") {
                return .roleDefault
            }

            return .roleDefault
        }
    }

    private func mapStorageError(_ error: Error) -> AppError {
        let message = error.localizedDescription.lowercased()
        if message.contains("bucket not found") || message.contains("not found") {
            return .backend("Chưa thể lưu ảnh đại diện. Vui lòng liên hệ quản trị viên.")
        }
        if message.contains("row-level security") || message.contains("permission denied") || message.contains("403") {
            return .permissionDenied
        }
        if message.contains("payload too large") || message.contains("exceeded") {
            return .validation("Ảnh đại diện quá lớn.")
        }
        if message.contains("network") || message.contains("failed to fetch") {
            return .backend("Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.")
        }
        return .backend("Không thể tải ảnh đại diện. Vui lòng thử lại.")
    }
}

private struct ProfileUpdatePayload: Encodable {
    let fullName: String
    let displayName: String
    let shortName: String
    let phone: String?
    let department: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case displayName = "display_name"
        case shortName = "short_name"
        case phone
        case department
    }
}

private struct ProfileAvatarUpdatePayload: Encodable {
    let avatarURL: String

    enum CodingKeys: String, CodingKey {
        case avatarURL = "avatar_url"
    }
}

private struct ProfileRow: Decodable {
    let id: UUID
    let email: String?
    let fullName: String?
    let displayName: String?
    let shortName: String?
    let phone: String?
    let role: String?
    let department: String?
    let avatarURL: String?
    let editorCode: String?
    let crewKey: String?
    let isEditorMember: Bool?
    let active: Bool?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case displayName = "display_name"
        case shortName = "short_name"
        case phone
        case role
        case department
        case avatarURL = "avatar_url"
        case editorCode = "editor_code"
        case crewKey = "crew_key"
        case isEditorMember = "is_editor_member"
        case active
        case isActive = "is_active"
    }

    func domain(session: AuthSessionSnapshot, override: UserPermissionOverride) -> CurrentUserProfile {
        let normalizedRole = AppRole.normalize(role)
        let fallbackName = session.displayName ?? session.email?.split(separator: "@").first.map(String.init) ?? "Nhân sự"
        let mappedDisplayName = displayName?.nilIfBlank ?? shortName?.nilIfBlank ?? fullName?.nilIfBlank ?? fallbackName
        let permissions = PermissionService.effectivePermissions(role: normalizedRole, override: override)

        return CurrentUserProfile(
            id: id,
            email: email?.nilIfBlank ?? session.email ?? "",
            fullName: fullName?.nilIfBlank ?? mappedDisplayName,
            displayName: mappedDisplayName,
            shortName: shortName?.nilIfBlank ?? mappedDisplayName,
            phone: phone ?? "",
            role: normalizedRole,
            rawRole: role,
            department: department?.nilIfBlank ?? "Team Marketing",
            avatarURL: avatarURL ?? "",
            editorCode: editorCode ?? "",
            crewKey: crewKey ?? "",
            isEditorMember: isEditorMember ?? (editorCode?.isEmpty == false || normalizedRole == .editor),
            isActive: isActive ?? active ?? true,
            permissionOverride: override,
            permissions: permissions
        )
    }
}

private struct PermissionOverrideRow: Decodable {
    let accessMode: String?
    let dashboardView: Bool?
    let calendarView: Bool?
    let calendarEdit: Bool?
    let tasksView: Bool?
    let tasksEdit: Bool?
    let contentPlanView: Bool?
    let contentPlanEditContent: Bool?
    let contentPlanAssignEditor: Bool?
    let usersManage: Bool?
    let profileEditSelf: Bool?

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

    var domain: UserPermissionOverride {
        UserPermissionOverride(
            accessMode: PermissionAccessMode(rawValue: accessMode ?? "") ?? .roleDefault,
            flags: [
                .dashboardView: dashboardView,
                .calendarView: calendarView,
                .calendarEdit: calendarEdit,
                .tasksView: tasksView,
                .tasksEdit: tasksEdit,
                .contentPlanView: contentPlanView,
                .contentPlanEditContent: contentPlanEditContent,
                .contentPlanAssignEditor: contentPlanAssignEditor,
                .usersManage: usersManage,
                .profileEditSelf: profileEditSelf,
            ]
        )
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
