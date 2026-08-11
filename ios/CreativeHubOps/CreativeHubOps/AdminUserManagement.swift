import Foundation
import Supabase

struct ManagedUserProfile: Identifiable, Equatable {
    let id: String
    let email: String
    let fullName: String
    let displayName: String
    let shortName: String
    let phone: String
    let role: AppRole
    let rawRole: String?
    let department: String
    let avatarURL: String
    let editorCode: String
    let crewKey: String
    let isEditorMember: Bool
    let isActive: Bool
    let permissionOverride: UserPermissionOverride
    let createdAt: String
    let updatedAt: String

    var roleLabel: String { role.label }

    var initials: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "N"
    }

    var permissionSummary: String {
        switch permissionOverride.accessMode {
        case .roleDefault: "Theo vai trò"
        case .viewOnly: "Chỉ xem"
        case .custom: "Tùy chỉnh"
        }
    }
}

struct AdminUserFormData: Equatable {
    var email = ""
    var password = ""
    var fullName = ""
    var displayName = ""
    var phone = ""
    var role: AppRole = .editor
    var department = "Team Marketing"
    var editorCode = ""
    var crewKey = ""
    var isEditorMember = true
    var isActive = true
    var permissionMode: PermissionAccessMode = .roleDefault
    var dashboardView = true
    var calendarView = true
    var calendarEdit = false
    var tasksView = true
    var tasksEdit = false
    var contentPlanView = true
    var contentPlanEditContent = false
    var contentPlanAssignEditor = false
    var usersManage = false
    var profileEditSelf = true

    init() {}

    init(profile: ManagedUserProfile) {
        email = profile.email
        fullName = profile.fullName
        displayName = profile.displayName
        phone = profile.phone
        role = profile.role
        department = profile.department
        editorCode = profile.editorCode
        crewKey = profile.crewKey
        isEditorMember = profile.isEditorMember
        isActive = profile.isActive
        permissionMode = profile.permissionOverride.accessMode

        let flags = profile.permissionOverride.flags
        dashboardView = (flags[.dashboardView] ?? nil) ?? true
        calendarView = (flags[.calendarView] ?? nil) ?? true
        calendarEdit = (flags[.calendarEdit] ?? nil) ?? false
        tasksView = (flags[.tasksView] ?? nil) ?? true
        tasksEdit = (flags[.tasksEdit] ?? nil) ?? false
        contentPlanView = (flags[.contentPlanView] ?? nil) ?? true
        contentPlanEditContent = (flags[.contentPlanEditContent] ?? nil) ?? false
        contentPlanAssignEditor = (flags[.contentPlanAssignEditor] ?? nil) ?? false
        usersManage = (flags[.usersManage] ?? nil) ?? false
        profileEditSelf = (flags[.profileEditSelf] ?? nil) ?? true
    }

    func validateForCreate() throws {
        try validateCommon()
        guard password.count >= 6 else {
            throw AppError.validation("Mật khẩu tạm thời cần tối thiểu 6 ký tự.")
        }
    }

    func validateForUpdate() throws {
        try validateCommon()
    }

    private func validateCommon() throws {
        guard email.trimmingCharacters(in: .whitespacesAndNewlines).contains("@") else {
            throw AppError.validation("Email chưa hợp lệ.")
        }
        guard !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.validation("Vui lòng nhập họ và tên.")
        }
        if isEditorMember, editorCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AppError.validation("Editor member cần có editor code.")
        }
    }
}

protocol AdminUserRepositoryServing: Sendable {
    func fetchUsers() async throws -> [ManagedUserProfile]
    func createUser(_ data: AdminUserFormData, actorId: UUID?) async throws
    func updateUser(_ profile: ManagedUserProfile, data: AdminUserFormData, actorId: UUID?) async throws
    func resetPassword(profile: ManagedUserProfile, password: String) async throws
    func deleteUser(_ profile: ManagedUserProfile) async throws
}

final class AdminUserRepository: AdminUserRepositoryServing {
    private let client: SupabaseClient

    init(config: AppConfig) {
        client = SupabaseClient(supabaseURL: config.supabaseURL, supabaseKey: config.supabaseAnonKey)
    }

    convenience init() throws {
        try self.init(config: AppConfig.current())
    }

    func fetchUsers() async throws -> [ManagedUserProfile] {
        let rows: [ManagedProfileRow] = try await client
            .from("profiles")
            .select("""
                id,
                email,
                full_name,
                display_name,
                short_name,
                phone,
                role,
                department,
                avatar_url,
                editor_code,
                crew_key,
                is_editor_member,
                active,
                is_active,
                created_at,
                updated_at
            """)
            .order("full_name", ascending: true)
            .execute()
            .value

        let overrides = try await fetchPermissionOverrides()
        return rows.map { row in
            row.domain(override: overrides[row.id])
        }
    }

    func createUser(_ data: AdminUserFormData, actorId: UUID?) async throws {
        try data.validateForCreate()
        let response: CreatedUserResponse = try await invokeFunction(
            "create-user",
            body: CreateUserFunctionPayload(data: data)
        )

        if let userId = response.userId, !userId.isEmpty {
            try await savePermissionOverride(profileId: userId, data: data, actorId: actorId)
        }
    }

    func updateUser(_ profile: ManagedUserProfile, data: AdminUserFormData, actorId: UUID?) async throws {
        try data.validateForUpdate()

        let nextEmail = data.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if nextEmail != profile.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            let _: EmptyFunctionResponse = try await invokeFunction(
                "manage-user",
                body: ManageUserPayload(action: "update_email", userId: profile.id, email: nextEmail)
            )
        }

        try await client
            .from("profiles")
            .update(ManagedProfileUpdatePayload(data: data))
            .eq("id", value: profile.id)
            .execute()

        try await savePermissionOverride(profileId: profile.id, data: data, actorId: actorId)
    }

    func resetPassword(profile: ManagedUserProfile, password: String) async throws {
        guard password.count >= 6 else {
            throw AppError.validation("Mật khẩu mới cần tối thiểu 6 ký tự.")
        }

        let _: EmptyFunctionResponse = try await invokeFunction(
            "manage-user",
            body: ManageUserPayload(action: "reset_password", userId: profile.id, password: password)
        )
    }

    func deleteUser(_ profile: ManagedUserProfile) async throws {
        let _: EmptyFunctionResponse = try await invokeFunction(
            "manage-user",
            body: ManageUserPayload(action: "delete_user", userId: profile.id)
        )
    }

    private func fetchPermissionOverrides() async throws -> [String: PermissionOverrideRow] {
        do {
            let rows: [PermissionOverrideRow] = try await client
                .from("user_permission_overrides")
                .select("""
                    profile_id,
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
                .execute()
                .value

            return Dictionary(uniqueKeysWithValues: rows.map { ($0.profileId, $0) })
        } catch {
            guard isMissingPermissionOverrideTable(error) else { throw error }
            return [:]
        }
    }

    private func savePermissionOverride(profileId: String, data: AdminUserFormData, actorId: UUID?) async throws {
        if data.permissionMode == .roleDefault {
            do {
                try await client
                    .from("user_permission_overrides")
                    .delete()
                    .eq("profile_id", value: profileId)
                    .execute()
            } catch {
                guard isMissingPermissionOverrideTable(error) else { throw error }
            }
            return
        }

        try await client
            .from("user_permission_overrides")
            .upsert(PermissionOverrideUpsertPayload(profileId: profileId, data: data, actorId: actorId), onConflict: "profile_id")
            .execute()
    }

    private func invokeFunction<Response: Decodable, Body: Encodable>(_ name: String, body: Body) async throws -> Response {
        let accessToken: String
        do {
            accessToken = try await client.auth.session.accessToken
        } catch {
            throw AppError.auth("Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.")
        }

        do {
            return try await client.functions.invoke(
                name,
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(accessToken)"],
                    body: body
                ),
                decoder: JSONDecoder()
            )
        } catch let error as FunctionsError {
            throw AppError.backend(Self.mapFunctionError(error))
        } catch {
            throw AppError.map(error, fallback: "Không thể xử lý tài khoản. Vui lòng thử lại.")
        }
    }

    private func isMissingPermissionOverrideTable(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("user_permission_overrides") ||
            message.contains("could not find the table") ||
            message.contains("pgrst205") ||
            message.contains("42p01")
    }

    private static func mapFunctionError(_ error: FunctionsError) -> String {
        switch error {
        case .relayError:
            return "Không thể xử lý tài khoản lúc này. Vui lòng liên hệ quản trị viên."
        case .httpError(_, let data):
            guard !data.isEmpty else {
                return "Không thể xử lý tài khoản lúc này. Vui lòng thử lại sau."
            }
            if let body = try? JSONDecoder().decode(FunctionErrorBody.self, from: data) {
                return body.error
            }
            return String(data: data, encoding: .utf8) ?? "Không thể xử lý tài khoản lúc này. Vui lòng thử lại sau."
        }
    }
}

@MainActor
final class AdminUsersViewModel: ObservableObject {
    @Published private(set) var users: [ManagedUserProfile] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var selectedUser: ManagedUserProfile?

    private var repository: AdminUserRepositoryServing?
    private var loadGeneration = 0
    private var sessionGeneration = 0

    init(repository: AdminUserRepositoryServing? = nil) {
        self.repository = repository
    }

    func load(force: Bool = false) async {
        guard force || (!isLoading && users.isEmpty) else { return }
        loadGeneration += 1
        let generation = loadGeneration
        let session = sessionGeneration

        isLoading = true
        errorMessage = nil
        defer {
            if isCurrentLoad(generation, session: session) {
                isLoading = false
            }
        }

        do {
            let repository = try makeRepository()
            let nextUsers = try await repository.fetchUsers()
            guard isCurrentLoad(generation, session: session) else { return }
            users = nextUsers
        } catch {
            guard isCurrentLoad(generation, session: session) else { return }
            users = []
            errorMessage = AppError.map(error, fallback: "Không thể tải nhân sự.").localizedDescription
        }
    }

    func createUser(_ data: AdminUserFormData, actorId: UUID?) async throws {
        try await perform(message: "Đã tạo thành viên.") {
            try await $0.createUser(data, actorId: actorId)
        }
    }

    func updateSelectedUser(_ data: AdminUserFormData, actorId: UUID?) async throws {
        guard let selectedUser else { throw AppError.validation("Chưa chọn thành viên.") }
        try await perform(message: "Đã cập nhật thành viên.") {
            try await $0.updateUser(selectedUser, data: data, actorId: actorId)
        }
    }

    func resetSelectedPassword(_ password: String) async throws {
        guard let selectedUser else { throw AppError.validation("Chưa chọn thành viên.") }
        try await perform(message: "Đã đặt lại mật khẩu.") {
            try await $0.resetPassword(profile: selectedUser, password: password)
        }
    }

    func deleteSelectedUser() async throws {
        guard let selectedUser else { throw AppError.validation("Chưa chọn thành viên.") }
        try await perform(message: "Đã xóa thành viên.") {
            try await $0.deleteUser(selectedUser)
        }
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    func clearForAccountSwitch() {
        sessionGeneration += 1
        loadGeneration += 1
        users = []
        isLoading = false
        isSaving = false
        errorMessage = nil
        successMessage = nil
        selectedUser = nil
    }

    private func perform(message: String, action: (AdminUserRepositoryServing) async throws -> Void) async throws {
        guard !isSaving else {
            throw AppError.validation("Thao tác đang xử lý. Vui lòng đợi trong giây lát.")
        }
        let session = sessionGeneration
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer {
            if isCurrentSession(session) {
                isSaving = false
            }
        }

        do {
            let repository = try makeRepository()
            try await action(repository)
            guard isCurrentSession(session) else { return }
            let nextUsers = try await repository.fetchUsers()
            guard isCurrentSession(session) else { return }
            users = nextUsers
            if let selectedUser {
                self.selectedUser = users.first { $0.id == selectedUser.id }
            }
            successMessage = message
        } catch {
            guard isCurrentSession(session) else { return }
            let mapped = AppError.map(error, fallback: "Không thể xử lý thành viên. Vui lòng thử lại.")
            errorMessage = mapped.localizedDescription
            throw mapped
        }
    }

    private func makeRepository() throws -> AdminUserRepositoryServing {
        if let repository { return repository }
        let repository = try AdminUserRepository()
        self.repository = repository
        return repository
    }

    private func isCurrentLoad(_ generation: Int, session: Int) -> Bool {
        generation == loadGeneration && isCurrentSession(session)
    }

    private func isCurrentSession(_ session: Int) -> Bool {
        session == sessionGeneration
    }
}

private struct ManagedProfileRow: Decodable {
    let id: String
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
    let createdAt: String?
    let updatedAt: String?

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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func domain(override: PermissionOverrideRow?) -> ManagedUserProfile {
        let normalizedRole = AppRole.normalize(role)
        let resolvedDisplayName = displayName ?? shortName ?? fullName ?? email ?? "Thành viên"
        let resolvedFullName = fullName ?? resolvedDisplayName
        return ManagedUserProfile(
            id: id,
            email: email ?? "",
            fullName: resolvedFullName,
            displayName: resolvedDisplayName,
            shortName: shortName ?? resolvedDisplayName,
            phone: phone ?? "",
            role: normalizedRole,
            rawRole: role,
            department: department ?? "Team Marketing",
            avatarURL: avatarURL ?? "",
            editorCode: editorCode ?? "",
            crewKey: crewKey ?? "",
            isEditorMember: isEditorMember ?? (!(editorCode ?? "").isEmpty || normalizedRole == .editor),
            isActive: isActive ?? active ?? true,
            permissionOverride: override?.domain ?? .roleDefault,
            createdAt: createdAt ?? "",
            updatedAt: updatedAt ?? createdAt ?? ""
        )
    }
}

private struct PermissionOverrideRow: Decodable {
    let profileId: String
    let accessMode: PermissionAccessMode?
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
        case profileId = "profile_id"
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
            accessMode: accessMode ?? .roleDefault,
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

private struct CreateUserFunctionPayload: Encodable {
    let email: String
    let password: String
    let fullName: String
    let displayName: String
    let phone: String
    let role: String
    let department: String
    let editorCode: String
    let isEditorMember: Bool
    let crewKey: String

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case fullName = "full_name"
        case displayName = "display_name"
        case phone
        case role
        case department
        case editorCode = "editor_code"
        case isEditorMember = "is_editor_member"
        case crewKey = "crew_key"
    }

    init(data: AdminUserFormData) {
        email = data.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        password = data.password
        fullName = data.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = data.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? fullName
            : data.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        phone = data.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        role = data.role.rawValue
        department = data.department.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Team Marketing"
            : data.department.trimmingCharacters(in: .whitespacesAndNewlines)
        editorCode = data.isEditorMember ? data.editorCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() : ""
        isEditorMember = data.isEditorMember
        crewKey = data.crewKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}

private struct ManagedProfileUpdatePayload: Encodable {
    let fullName: String
    let displayName: String
    let shortName: String
    let phone: String?
    let role: String
    let department: String
    let editorCode: String?
    let crewKey: String?
    let isEditorMember: Bool
    let active: Bool
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case displayName = "display_name"
        case shortName = "short_name"
        case phone
        case role
        case department
        case editorCode = "editor_code"
        case crewKey = "crew_key"
        case isEditorMember = "is_editor_member"
        case active
        case isActive = "is_active"
    }

    init(data: AdminUserFormData) {
        let resolvedFullName = data.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = data.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? resolvedFullName
            : data.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        fullName = resolvedFullName
        displayName = resolvedDisplayName
        shortName = resolvedDisplayName
        phone = data.phone.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        role = data.role.rawValue
        department = data.department.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Team Marketing"
        editorCode = data.isEditorMember ? data.editorCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().nilIfEmpty : nil
        crewKey = data.crewKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().nilIfEmpty
        isEditorMember = data.isEditorMember
        active = data.isActive
        isActive = data.isActive
    }
}

private struct PermissionOverrideUpsertPayload: Encodable {
    let profileId: String
    let accessMode: PermissionAccessMode
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
    let updatedBy: String?

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
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
        case updatedBy = "updated_by"
    }

    init(profileId: String, data: AdminUserFormData, actorId: UUID?) {
        self.profileId = profileId
        accessMode = data.permissionMode
        let usesCustomFlags = data.permissionMode == .custom
        dashboardView = usesCustomFlags ? data.dashboardView : nil
        calendarView = usesCustomFlags ? data.calendarView : nil
        calendarEdit = usesCustomFlags ? data.calendarEdit : nil
        tasksView = usesCustomFlags ? data.tasksView : nil
        tasksEdit = usesCustomFlags ? data.tasksEdit : nil
        contentPlanView = usesCustomFlags ? data.contentPlanView : nil
        contentPlanEditContent = usesCustomFlags ? data.contentPlanEditContent : nil
        contentPlanAssignEditor = usesCustomFlags ? data.contentPlanAssignEditor : nil
        usersManage = usesCustomFlags ? data.usersManage : nil
        profileEditSelf = usesCustomFlags ? data.profileEditSelf : nil
        updatedBy = actorId?.uuidString
    }
}

private struct ManageUserPayload: Encodable {
    let action: String
    let userId: String
    let email: String?
    let password: String?

    enum CodingKeys: String, CodingKey {
        case action
        case userId = "user_id"
        case email
        case password
    }

    init(action: String, userId: String, email: String? = nil, password: String? = nil) {
        self.action = action
        self.userId = userId
        self.email = email
        self.password = password
    }
}

private struct CreatedUserResponse: Decodable {
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

private struct EmptyFunctionResponse: Decodable {}

private struct FunctionErrorBody: Decodable {
    let error: String
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
