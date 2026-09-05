import Foundation
import SwiftUI
import Supabase

enum MemberRole: String, CaseIterable, Identifiable, Equatable, Sendable, Codable {
    case admin
    case creativeManager = "creative_manager"
    case contentCreator = "content_creator"
    case editor

    init(rawValue: String?) {
        switch rawValue {
        case "admin":
            self = .admin
        case "creative_manager", "team_lead":
            self = .creativeManager
        case "content_creator":
            self = .contentCreator
        default:
            self = .editor
        }
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .admin: "Quản trị viên"
        case .creativeManager: "Creative Manager"
        case .contentCreator: "Content Creator"
        case .editor: "Editor"
        }
    }

    var compactLabel: String {
        switch self {
        case .admin: "Admin"
        case .creativeManager: "Manager"
        case .contentCreator: "Creator"
        case .editor: "Editor"
        }
    }

    var tint: Color {
        switch self {
        case .admin: CHColors.purple
        case .creativeManager: CHColors.green
        case .contentCreator: CHColors.orange
        case .editor: CHColors.blue
        }
    }
}

enum MemberPermissionMode: String, CaseIterable, Identifiable, Equatable, Sendable, Codable {
    case roleDefault = "role_default"
    case viewOnly = "view_only"
    case custom

    init(rawValue: String?) {
        switch rawValue {
        case "view_only":
            self = .viewOnly
        case "custom":
            self = .custom
        default:
            self = .roleDefault
        }
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .roleDefault: "Theo vai trò"
        case .viewOnly: "Chỉ xem"
        case .custom: "Tùy chỉnh"
        }
    }
}

enum MemberCopy {
    static let roleStatsHeading = "Vai trò"
    static let permissionSummarySuffix = "Quyền sử dụng được áp dụng theo chế độ đã chọn."
    static let deleteConsequence = "Tài khoản đăng nhập sẽ bị xóa vĩnh viễn. Các phân công và bản ghi liên quan trong hệ thống sẽ được gỡ khỏi thành viên này trước khi xóa hồ sơ."
}

enum MemberStatusFilter: String, CaseIterable, Identifiable, Equatable {
    case all
    case active
    case inactive

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "Tất cả"
        case .active: "Hoạt động"
        case .inactive: "Tạm khóa"
        }
    }
}

enum MemberRoleFilter: String, CaseIterable, Identifiable, Equatable {
    case all
    case admin
    case creativeManager
    case contentCreator
    case editor

    var id: String { rawValue }

    var role: MemberRole? {
        switch self {
        case .all: nil
        case .admin: .admin
        case .creativeManager: .creativeManager
        case .contentCreator: .contentCreator
        case .editor: .editor
        }
    }

    var label: String {
        role?.compactLabel ?? "Tất cả"
    }
}

struct MemberPermissions: Equatable, Sendable {
    var canView: Bool
    var canCreate: Bool
    var canUpdate: Bool
    var isAdmin: Bool
    var currentProfileID: UUID?

    var canManage: Bool {
        canCreate && canUpdate && isAdmin
    }

    static let readonly = MemberPermissions(canView: true, canCreate: false, canUpdate: false, isAdmin: false, currentProfileID: nil)
    static let admin = MemberPermissions(canView: true, canCreate: true, canUpdate: true, isAdmin: true, currentProfileID: nil)
}

struct MemberProfile: Identifiable, Equatable, Sendable {
    var id: UUID
    var email: String
    var fullName: String
    var displayName: String
    var phone: String
    var role: MemberRole
    var department: String
    var avatarURL: URL?
    var editorCode: String
    var crewKey: String
    var isEditorMember: Bool
    var isActive: Bool
    var permissionMode: MemberPermissionMode
    var createdAt: String
    var updatedAt: String

    var titleName: String {
        fullName.nonEmptyMember ?? displayName.nonEmptyMember ?? email.nonEmptyMember ?? "Thành viên"
    }

    var subtitleName: String {
        displayName.nonEmptyMember ?? titleName
    }

    var initials: String {
        let source = subtitleName
        let parts = source.split(separator: " ")
        let raw = parts.count >= 2
            ? "\(parts[parts.count - 2].prefix(1))\(parts[parts.count - 1].prefix(1))"
            : String(source.prefix(2))
        return raw.uppercased()
    }

    var searchTokens: [String] {
        [fullName, displayName, email, department, editorCode, crewKey, role.label, role.compactLabel]
    }

    func canDelete(relativeTo permissions: MemberPermissions) -> Bool {
        permissions.canManage && permissions.currentProfileID != id
    }
}

struct MemberFormData: Equatable, Sendable {
    var fullName = ""
    var displayName = ""
    var email = ""
    var password = ""
    var phone = ""
    var role: MemberRole = .editor
    var department = "Team Marketing"
    var editorCode = ""
    var crewKey = ""
    var isEditorMember = false
    var isActive = true
    var permissionMode: MemberPermissionMode = .roleDefault

    static let emptyCreate = MemberFormData()

    init() {}

    init(member: MemberProfile) {
        fullName = member.fullName
        displayName = member.displayName
        email = member.email
        phone = member.phone
        role = member.role
        department = member.department
        editorCode = member.editorCode
        crewKey = member.crewKey
        isEditorMember = member.isEditorMember
        isActive = member.isActive
        permissionMode = member.permissionMode
    }
}

enum MemberModuleMode: Equatable {
    case create
    case detail(MemberProfile)
    case edit(MemberProfile)

    var title: String {
        switch self {
        case .create: "Thêm thành viên"
        case .detail: "Chi tiết thành viên"
        case .edit: "Sửa thành viên"
        }
    }

    var openedMember: MemberProfile? {
        switch self {
        case .create: nil
        case .detail(let member), .edit(let member): member
        }
    }
}

enum MemberRepositoryError: Error, Equatable {
    case configurationMissing
    case validation(String)
    case backend(String)
}

protocol MemberDataProviding: Sendable {
    var usesProductionData: Bool { get }
    func fetchMembers() async throws -> [MemberProfile]
    func createMember(_ data: MemberFormData, actorID: UUID?) async throws
    func updateMember(id: UUID, data: MemberFormData, previous: MemberProfile, actorID: UUID?) async throws
    func deleteMember(_ member: MemberProfile) async throws
    func resetPassword(member: MemberProfile, password: String) async throws
}

struct MemberSupabaseRepository: MemberDataProviding {
    var usesProductionData: Bool { true }

    private let client: SupabaseClient?
    private let pageSize = 1_000

    init(client: SupabaseClient? = SupabaseService.shared.client) {
        self.client = client
    }

    func fetchMembers() async throws -> [MemberProfile] {
        guard let client else { throw MemberRepositoryError.configurationMissing }
        var rows: [MemberProfileDTO] = []
        var offset = 0

        while true {
            let page: [MemberProfileDTO] = try await client
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
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            rows.append(contentsOf: page)
            guard page.count == pageSize else { break }
            offset += pageSize
        }

        let overrides = try await fetchPermissionOverrides(client: client)
        return rows
            .map { $0.member(permissionMode: overrides[$0.id] ?? .roleDefault) }
            .sorted { $0.titleName.localizedCompare($1.titleName) == .orderedAscending }
    }

    func createMember(_ data: MemberFormData, actorID: UUID?) async throws {
        guard let client else { throw MemberRepositoryError.configurationMissing }
        try MemberValidator.validate(data, mode: .create)
        let response: MemberCreateFunctionResponse = try await client.functions.invoke(
            "create-user",
            options: FunctionInvokeOptions(body: MemberCreateFunctionBody(data: data))
        )
        if data.permissionMode != .roleDefault {
            try await savePermissionOverride(profileID: response.userID, mode: data.permissionMode, actorID: actorID)
        }
    }

    func updateMember(id: UUID, data: MemberFormData, previous: MemberProfile, actorID: UUID?) async throws {
        guard let client else { throw MemberRepositoryError.configurationMissing }
        try MemberValidator.validate(data, mode: .edit)

        if data.email.normalizedMemberEmail != previous.email.normalizedMemberEmail {
            try await invokeManageUser(client: client, body: MemberManageUserBody(
                action: "update_email",
                userID: id,
                email: data.email.normalizedMemberEmail,
                password: nil
            ))
        }

        _ = try await client
            .from("profiles")
            .update(MemberProfilePayload(data: data))
            .eq("id", value: id)
            .execute()

        try await savePermissionOverride(profileID: id, mode: data.permissionMode, actorID: actorID)
    }

    func deleteMember(_ member: MemberProfile) async throws {
        guard let client else { throw MemberRepositoryError.configurationMissing }
        try await invokeManageUser(client: client, body: MemberManageUserBody(
            action: "delete_user",
            userID: member.id,
            email: nil,
            password: nil
        ))
    }

    func resetPassword(member: MemberProfile, password: String) async throws {
        guard let client else { throw MemberRepositoryError.configurationMissing }
        guard password.count >= 8 else {
            throw MemberRepositoryError.validation("Mật khẩu mới cần tối thiểu 8 ký tự.")
        }
        try await invokeManageUser(client: client, body: MemberManageUserBody(
            action: "reset_password",
            userID: member.id,
            email: nil,
            password: password
        ))
    }

    private func fetchPermissionOverrides(client: SupabaseClient) async throws -> [UUID: MemberPermissionMode] {
        do {
            let rows: [MemberPermissionOverrideDTO] = try await client
                .from("user_permission_overrides")
                .select("profile_id, access_mode")
                .execute()
                .value
            return Dictionary(uniqueKeysWithValues: rows.map { ($0.profileID, MemberPermissionMode(rawValue: $0.accessMode)) })
        } catch let error as PostgrestError {
            if Self.isMissingOverrideTable(error) {
                return [:]
            }
            throw MemberRepositoryError.backend(error.message)
        }
    }

    private func savePermissionOverride(profileID: UUID, mode: MemberPermissionMode, actorID: UUID?) async throws {
        guard let client else { throw MemberRepositoryError.configurationMissing }
        if mode == .roleDefault {
            do {
                _ = try await client
                    .from("user_permission_overrides")
                    .delete()
                    .eq("profile_id", value: profileID)
                    .execute()
            } catch let error as PostgrestError where Self.isMissingOverrideTable(error) {
                return
            }
            return
        }

        do {
            _ = try await client
                .from("user_permission_overrides")
                .upsert(MemberPermissionOverridePayload(profileID: profileID, mode: mode, actorID: actorID), onConflict: "profile_id")
                .execute()
        } catch let error as PostgrestError {
            if Self.isMissingOverrideTable(error) {
                throw MemberRepositoryError.backend("Quản lý quyền thành viên chưa sẵn sàng.")
            }
            throw MemberRepositoryError.backend(error.message)
        }
    }

    private func invokeManageUser(client: SupabaseClient, body: MemberManageUserBody) async throws {
        do {
            try await client.functions.invoke("manage-user", options: FunctionInvokeOptions(body: body))
        } catch let error as FunctionsError {
            throw MemberRepositoryError.backend(Self.functionMessage(error))
        } catch {
            throw MemberRepositoryError.backend(error.localizedDescription)
        }
    }

    private static func isMissingOverrideTable(_ error: PostgrestError) -> Bool {
        let message = error.message.lowercased()
        return error.code == "42P01" ||
            error.code == "PGRST205" ||
            message.contains("user_permission_overrides") ||
            message.contains("could not find the table")
    }

    private static func functionMessage(_ error: FunctionsError) -> String {
        switch error {
        case .httpError(_, let data):
            if
                let body = try? JSONDecoder().decode(MemberFunctionErrorBody.self, from: data),
                let message = body.error.nonEmptyMember
            {
                return message
            }
            return "Không thể xử lý tài khoản lúc này. Vui lòng thử lại sau."
        default:
            return "Không thể xử lý tài khoản lúc này. Vui lòng thử lại sau."
        }
    }
}

private struct MemberProfileDTO: Decodable {
    var id: UUID
    var email: String?
    var fullName: String?
    var displayName: String?
    var shortName: String?
    var phone: String?
    var role: String?
    var department: String?
    var avatarURL: String?
    var editorCode: String?
    var crewKey: String?
    var isEditorMember: Bool?
    var active: Bool?
    var isActive: Bool?
    var createdAt: String?
    var updatedAt: String?

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

    func member(permissionMode: MemberPermissionMode) -> MemberProfile {
        let roleValue = MemberRole(rawValue: role)
        let display = displayName.nonEmptyMember ?? shortName.nonEmptyMember ?? fullName.nonEmptyMember ?? email.nonEmptyMember ?? "Thành viên"
        return MemberProfile(
            id: id,
            email: email ?? "",
            fullName: fullName.nonEmptyMember ?? display,
            displayName: display,
            phone: phone ?? "",
            role: roleValue,
            department: department.nonEmptyMember ?? "Team Marketing",
            avatarURL: avatarURL.nonEmptyMember.flatMap(URL.init(string:)),
            editorCode: editorCode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "",
            crewKey: crewKey?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? "",
            isEditorMember: isEditorMember ?? (editorCode.nonEmptyMember != nil || roleValue == .editor),
            isActive: isActive ?? active ?? true,
            permissionMode: permissionMode,
            createdAt: createdAt ?? "",
            updatedAt: updatedAt ?? createdAt ?? ""
        )
    }
}

private struct MemberPermissionOverrideDTO: Decodable {
    var profileID: UUID
    var accessMode: String?

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case accessMode = "access_mode"
    }
}

private struct MemberProfilePayload: Encodable {
    var fullName: String
    var displayName: String
    var shortName: String
    var phone: String?
    var role: String
    var department: String
    var editorCode: String?
    var crewKey: String?
    var isEditorMember: Bool
    var active: Bool
    var isActive: Bool

    init(data: MemberFormData) {
        fullName = data.fullName.trimmedMember
        displayName = data.displayName.trimmedMember
        shortName = data.displayName.trimmedMember
        phone = data.phone.trimmedMember.nilIfEmptyMember
        role = data.role.rawValue
        department = data.department.trimmedMember.nilIfEmptyMember ?? "Team Marketing"
        editorCode = data.isEditorMember ? data.editorCode.trimmedMember.lowercased().nilIfEmptyMember : nil
        crewKey = data.crewKey.trimmedMember.uppercased().nilIfEmptyMember
        isEditorMember = data.isEditorMember
        active = data.isActive
        isActive = data.isActive
    }

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
}

private struct MemberPermissionOverridePayload: Encodable {
    var profileID: UUID
    var accessMode: String
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
    var updatedBy: UUID?

    init(profileID: UUID, mode: MemberPermissionMode, actorID: UUID?) {
        self.profileID = profileID
        accessMode = mode.rawValue
        dashboardView = mode == .custom ? true : nil
        calendarView = mode == .custom ? true : nil
        calendarEdit = mode == .custom ? false : nil
        tasksView = mode == .custom ? true : nil
        tasksEdit = mode == .custom ? false : nil
        contentPlanView = mode == .custom ? true : nil
        contentPlanEditContent = mode == .custom ? false : nil
        contentPlanAssignEditor = mode == .custom ? false : nil
        usersManage = nil
        profileEditSelf = mode == .viewOnly ? false : nil
        updatedBy = actorID
    }

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
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
}

private struct MemberCreateFunctionBody: Encodable {
    var email: String
    var password: String
    var fullName: String
    var displayName: String
    var phone: String
    var role: String
    var department: String
    var editorCode: String
    var isEditorMember: Bool
    var crewKey: String

    init(data: MemberFormData) {
        email = data.email.normalizedMemberEmail
        password = data.password
        fullName = data.fullName.trimmedMember
        displayName = data.displayName.trimmedMember.nilIfEmptyMember ?? data.fullName.trimmedMember
        phone = data.phone.trimmedMember
        role = data.role.rawValue
        department = data.department.trimmedMember.nilIfEmptyMember ?? "Team Marketing"
        editorCode = data.isEditorMember ? data.editorCode.trimmedMember.lowercased() : ""
        isEditorMember = data.isEditorMember
        crewKey = data.crewKey.trimmedMember.uppercased()
    }

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
}

private struct MemberCreateFunctionResponse: Decodable {
    var userID: UUID

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
    }
}

private struct MemberManageUserBody: Encodable {
    var action: String
    var userID: UUID
    var email: String?
    var password: String?

    enum CodingKeys: String, CodingKey {
        case action
        case userID = "user_id"
        case email
        case password
    }
}

private struct MemberFunctionErrorBody: Decodable {
    var error: String?
}

enum MemberValidationMode {
    case create
    case edit
}

enum MemberValidator {
    static func validate(_ data: MemberFormData, mode: MemberValidationMode) throws {
        guard !data.fullName.trimmedMember.isEmpty else {
            throw MemberRepositoryError.validation("Vui lòng nhập họ tên.")
        }
        guard !data.displayName.trimmedMember.isEmpty else {
            throw MemberRepositoryError.validation("Vui lòng nhập tên hiển thị.")
        }
        guard data.email.normalizedMemberEmail.contains("@"), data.email.normalizedMemberEmail.contains(".") else {
            throw MemberRepositoryError.validation("Email chưa đúng định dạng.")
        }
        if mode == .create, data.password.count < 8 {
            throw MemberRepositoryError.validation("Mật khẩu tạm cần tối thiểu 8 ký tự.")
        }
        if data.isEditorMember, data.editorCode.trimmedMember.isEmpty {
            throw MemberRepositoryError.validation("Vui lòng nhập Editor Code cho thành viên team editor.")
        }
        if data.editorCode.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            throw MemberRepositoryError.validation("Editor Code không được có khoảng trắng.")
        }
    }
}

#if DEBUG
actor MemberFixtureRepository: MemberDataProviding {
    nonisolated var usesProductionData: Bool { false }
    private var members: [MemberProfile]
    private let mode: String

    init(mode: String = ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE8_MEMBERS_FIXTURE"] ?? "full") {
        self.mode = mode
        members = Self.seedMembers
    }

    func fetchMembers() async throws -> [MemberProfile] {
        if mode == "error" {
            throw MemberRepositoryError.backend("Fixture Supabase SQL members error")
        }
        if mode == "empty" {
            return []
        }
        return members.sorted { $0.titleName.localizedCompare($1.titleName) == .orderedAscending }
    }

    func createMember(_ data: MemberFormData, actorID: UUID?) async throws {
        try MemberValidator.validate(data, mode: .create)
        let member = MemberProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000899") ?? UUID(),
            email: data.email.normalizedMemberEmail,
            fullName: data.fullName.trimmedMember,
            displayName: data.displayName.trimmedMember,
            phone: data.phone.trimmedMember,
            role: data.role,
            department: data.department.trimmedMember.nilIfEmptyMember ?? "Team Marketing",
            avatarURL: nil,
            editorCode: data.isEditorMember ? data.editorCode.trimmedMember.lowercased() : "",
            crewKey: data.crewKey.trimmedMember.uppercased(),
            isEditorMember: data.isEditorMember,
            isActive: true,
            permissionMode: data.permissionMode,
            createdAt: "2026-08-21T00:00:00Z",
            updatedAt: "2026-08-21T00:00:00Z"
        )
        members.append(member)
    }

    func updateMember(id: UUID, data: MemberFormData, previous: MemberProfile, actorID: UUID?) async throws {
        try MemberValidator.validate(data, mode: .edit)
        guard let index = members.firstIndex(where: { $0.id == id }) else {
            throw MemberRepositoryError.backend("Không tìm thấy thành viên.")
        }
        members[index].email = data.email.normalizedMemberEmail
        members[index].fullName = data.fullName.trimmedMember
        members[index].displayName = data.displayName.trimmedMember
        members[index].phone = data.phone.trimmedMember
        members[index].role = data.role
        members[index].department = data.department.trimmedMember.nilIfEmptyMember ?? "Team Marketing"
        members[index].editorCode = data.isEditorMember ? data.editorCode.trimmedMember.lowercased() : ""
        members[index].crewKey = data.crewKey.trimmedMember.uppercased()
        members[index].isEditorMember = data.isEditorMember
        members[index].isActive = data.isActive
        members[index].permissionMode = data.permissionMode
    }

    func deleteMember(_ member: MemberProfile) async throws {
        members.removeAll { $0.id == member.id }
    }

    func resetPassword(member: MemberProfile, password: String) async throws {
        guard password.count >= 8 else {
            throw MemberRepositoryError.validation("Mật khẩu mới cần tối thiểu 8 ký tự.")
        }
    }

    static let seedMembers: [MemberProfile] = [
        MemberProfile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000801")!, email: "dat.dq@company.com", fullName: "Đoàn Quốc Đạt", displayName: "Đạt", phone: "0901 111 111", role: .admin, department: "Team Marketing", avatarURL: nil, editorCode: "dat", crewKey: "ĐẠT", isEditorMember: true, isActive: true, permissionMode: .roleDefault, createdAt: "2026-08-01", updatedAt: "2026-08-12"),
        MemberProfile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000802")!, email: "hai.nt@company.com", fullName: "Nguyễn Thanh Hải", displayName: "Hải", phone: "0902 222 222", role: .editor, department: "Video Team", avatarURL: nil, editorCode: "hai", crewKey: "HẢI", isEditorMember: true, isActive: true, permissionMode: .roleDefault, createdAt: "2026-08-01", updatedAt: "2026-08-12"),
        MemberProfile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000803")!, email: "minh.hhl@company.com", fullName: "Hoàng Hữu Lê Minh", displayName: "Minh", phone: "0903 333 333", role: .editor, department: "Video Team", avatarURL: nil, editorCode: "minh", crewKey: "MINH", isEditorMember: true, isActive: true, permissionMode: .custom, createdAt: "2026-08-01", updatedAt: "2026-08-12"),
        MemberProfile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000804")!, email: "khang.bg@company.com", fullName: "Bùi Gia Khang", displayName: "Khang", phone: "0904 444 444", role: .creativeManager, department: "Creative", avatarURL: nil, editorCode: "", crewKey: "", isEditorMember: false, isActive: true, permissionMode: .roleDefault, createdAt: "2026-08-01", updatedAt: "2026-08-12"),
        MemberProfile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000805")!, email: "bumi.nv@company.com", fullName: "Nguyễn Vũ Bumi", displayName: "Bumi", phone: "0905 555 555", role: .contentCreator, department: "Content", avatarURL: nil, editorCode: "", crewKey: "BUMI", isEditorMember: false, isActive: true, permissionMode: .roleDefault, createdAt: "2026-08-01", updatedAt: "2026-08-12"),
        MemberProfile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000806")!, email: "old.editor@company.com", fullName: "Trần Editor Cũ", displayName: "Editor Cũ", phone: "", role: .editor, department: "Video Team", avatarURL: nil, editorCode: "old", crewKey: "OLD", isEditorMember: true, isActive: false, permissionMode: .viewOnly, createdAt: "2026-07-01", updatedAt: "2026-08-10")
    ]
}
#endif

@MainActor
final class MembersViewModel: ObservableObject {
    @Published private(set) var members: [MemberProfile] = []
    @Published var searchText = ""
    @Published var roleFilter: MemberRoleFilter = .all
    @Published var statusFilter: MemberStatusFilter = .all
    @Published private(set) var isLoading = false
    @Published private(set) var isMutating = false
    @Published var loadError: String?
    @Published var mutationError: String?
    @Published var moduleMode: MemberModuleMode?
    @Published var draft = MemberFormData()
    @Published var pendingDelete: MemberProfile?
    @Published var pendingResetPassword: MemberProfile?

    let provider: MemberDataProviding

    init(provider: MemberDataProviding? = nil) {
        #if DEBUG
        if let provider {
            self.provider = provider
        } else if ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE8_MEMBERS_FIXTURE"] != nil {
            self.provider = MemberFixtureRepository()
        } else {
            self.provider = MemberSupabaseRepository()
        }
        #else
        self.provider = provider ?? MemberSupabaseRepository()
        #endif
    }

    var filteredMembers: [MemberProfile] {
        let query = searchText.trimmedMember.lowercased()
        return members.filter { member in
            if let role = roleFilter.role, member.role != role { return false }
            if statusFilter == .active, !member.isActive { return false }
            if statusFilter == .inactive, member.isActive { return false }
            guard !query.isEmpty else { return true }
            return member.searchTokens.contains { $0.lowercased().contains(query) }
        }
    }

    var isFiltering: Bool {
        !searchText.trimmedMember.isEmpty || roleFilter != .all || statusFilter != .all
    }

    var roleStats: [(MemberRole, Int)] {
        MemberRole.allCases.map { role in
            (role, members.filter { $0.role == role }.count)
        }
    }

    var editorCount: Int {
        members.filter(\.isEditorMember).count
    }

    var activeCount: Int {
        members.filter(\.isActive).count
    }

    func load() async {
        isLoading = true
        loadError = nil
        do {
            members = try await provider.fetchMembers()
        } catch {
            if AsyncCancellation.isCancellation(error) {
                isLoading = false
                return
            }
            members = []
            loadError = Self.safeMessage(for: error, fallback: "Không thể tải danh sách thành viên. Vui lòng thử lại.")
        }
        isLoading = false
    }

    func refresh() async -> String? {
        do {
            members = try await provider.fetchMembers()
            loadError = nil
            return nil
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return nil
            }
            let message = Self.safeMessage(for: error, fallback: "Không thể tải danh sách thành viên. Vui lòng thử lại.")
            if members.isEmpty {
                loadError = message
            }
            return message
        }
    }

    func resetFilters() {
        searchText = ""
        roleFilter = .all
        statusFilter = .all
    }

    func openCreate() {
        draft = .emptyCreate
        mutationError = nil
        moduleMode = .create
    }

    func open(member: MemberProfile, permissions: MemberPermissions) {
        draft = MemberFormData(member: member)
        mutationError = nil
        moduleMode = permissions.canUpdate ? .edit(member) : .detail(member)
    }

    func clearModule() {
        moduleMode = nil
        mutationError = nil
        pendingDelete = nil
        pendingResetPassword = nil
    }

    func save(permissions: MemberPermissions) async -> CHToastItem? {
        mutationError = nil
        guard permissions.canManage || (moduleMode?.openedMember != nil && permissions.canUpdate) else {
            mutationError = "Bạn không có quyền quản lý thành viên."
            return nil
        }

        isMutating = true
        defer { isMutating = false }

        do {
            switch moduleMode {
            case .create:
                guard permissions.canCreate else { throw MemberRepositoryError.validation("Bạn không có quyền tạo thành viên.") }
                try await provider.createMember(draft, actorID: permissions.currentProfileID)
                try await reloadCanonical()
                return CHToastItem(kind: .success, message: "Đã tạo thành viên mới.")
            case .edit(let previous):
                guard permissions.canUpdate else { throw MemberRepositoryError.validation("Bạn không có quyền sửa thành viên.") }
                try await provider.updateMember(id: previous.id, data: draft, previous: previous, actorID: permissions.currentProfileID)
                try await reloadCanonical()
                return CHToastItem(kind: .success, message: "Đã lưu thông tin thành viên.")
            case .detail, .none:
                return nil
            }
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return nil
            }
            mutationError = Self.safeMessage(for: error, fallback: "Không thể lưu thông tin thành viên. Vui lòng thử lại.")
            return nil
        }
    }

    func deletePending(permissions: MemberPermissions) async -> CHToastItem? {
        guard let member = pendingDelete else { return nil }
        guard member.canDelete(relativeTo: permissions) else {
            mutationError = "Không thể xóa tài khoản này."
            return nil
        }
        isMutating = true
        defer { isMutating = false }
        do {
            try await provider.deleteMember(member)
            try await reloadCanonical()
            pendingDelete = nil
            return CHToastItem(kind: .success, message: "Đã xóa tài khoản.")
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return nil
            }
            mutationError = Self.safeMessage(for: error, fallback: "Không thể xóa tài khoản. Vui lòng thử lại.")
            return nil
        }
    }

    func resetPassword(_ password: String, permissions: MemberPermissions) async -> CHToastItem? {
        guard let member = pendingResetPassword, permissions.canManage else {
            mutationError = "Bạn không có quyền reset mật khẩu."
            return nil
        }
        isMutating = true
        defer { isMutating = false }
        do {
            try await provider.resetPassword(member: member, password: password)
            pendingResetPassword = nil
            return CHToastItem(kind: .success, message: "Đã reset mật khẩu tài khoản.")
        } catch {
            if AsyncCancellation.isCancellation(error) {
                return nil
            }
            mutationError = Self.safeMessage(for: error, fallback: "Không thể reset mật khẩu. Vui lòng thử lại.")
            return nil
        }
    }

    private func reloadCanonical() async throws {
        members = try await provider.fetchMembers()
    }

    static func safeMessage(for error: Error, fallback: String) -> String {
        if AsyncCancellation.isCancellation(error) {
            return fallback
        }
        let raw: String
        if let repositoryError = error as? MemberRepositoryError {
            switch repositoryError {
            case .configurationMissing:
                raw = "Quản lý thành viên chưa sẵn sàng. Vui lòng liên hệ quản trị viên."
            case .validation(let message), .backend(let message):
                raw = message
            }
        } else {
            raw = error.localizedDescription
        }

        let lower = raw.lowercased()
        if lower.contains("fixture") ||
            lower.contains("supabase") ||
            lower.contains("rpc") ||
            lower.contains("sql") ||
            lower.contains("postgrest") ||
            lower.contains("service_role") ||
            lower.contains("authorization") {
            return fallback
        }
        return raw.nonEmptyMember ?? fallback
    }
}

struct MembersPlaceholderView: View {
    @ObservedObject var viewModel: MembersViewModel
    var isToolsOpen: Bool
    var permissions: MemberPermissions
    var openModule: (ModuleDestination) -> Void

    init(
        viewModel: MembersViewModel = MembersViewModel(),
        isToolsOpen: Bool = false,
        permissions: MemberPermissions = .admin,
        openModule: @escaping (ModuleDestination) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.isToolsOpen = isToolsOpen
        self.permissions = permissions
        self.openModule = openModule
    }

    var body: some View {
        VStack(spacing: 12) {
            searchBar

            if isToolsOpen {
                MembersToolsPanel(viewModel: viewModel)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityIdentifier("members.tools")
            }

            headerRow

            content

            departmentStats
                .padding(.bottom, 120)
        }
        .accessibilityIdentifier("members.root")
        .task {
            if viewModel.members.isEmpty && !viewModel.isLoading && viewModel.loadError == nil {
                await viewModel.load()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CHColors.muted)
            TextField("Tìm nhân sự...", text: $viewModel.searchText)
                .font(CHTypography.body)
                .foregroundStyle(CHColors.ink)
                .tint(CHColors.purple)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("members.search")
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(CHColors.muted)
                }
                .accessibilityIdentifier("members.search.clear")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(CHColors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(CHColors.line))
    }

    private var headerRow: some View {
        HStack {
            Text("\(viewModel.filteredMembers.count) thành viên")
                .font(CHTypography.caption.weight(.bold))
                .foregroundStyle(CHColors.muted)
                .accessibilityIdentifier("members.count")
            Spacer()
            if permissions.canCreate {
                Button {
                    viewModel.openCreate()
                    openModule(.memberCreate)
                } label: {
                    Label("Thêm", systemImage: "person.badge.plus")
                }
                .buttonStyle(CHPrimaryButtonStyle())
                .accessibilityIdentifier("members.add")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            CHCard {
                CHStateView(kind: .loading, title: "Đang tải thành viên")
                    .frame(minHeight: 320)
            }
            .accessibilityIdentifier("members.loading")
        } else if let loadError = viewModel.loadError {
            CHCard {
                CHStateView(
                    kind: .error,
                    title: "Không thể tải thành viên",
                    message: loadError,
                    actionTitle: "Thử lại",
                    action: {
                        Task { await viewModel.load() }
                    }
                )
                .frame(minHeight: 320)
            }
            .accessibilityIdentifier("members.load-error")
        } else if viewModel.members.isEmpty {
            CHCard {
                CHStateView(
                    kind: .empty,
                    title: "Chưa có thành viên",
                    message: "Tạo tài khoản đầu tiên cho team.",
                    actionTitle: permissions.canCreate ? "Thêm thành viên" : nil,
                    action: permissions.canCreate ? {
                        viewModel.openCreate()
                        openModule(.memberCreate)
                    } : nil
                )
                .frame(minHeight: 320)
            }
            .accessibilityIdentifier("members.empty")
        } else if viewModel.filteredMembers.isEmpty {
            CHCard {
                CHStateView(
                    kind: .empty,
                    title: "Không có thành viên phù hợp",
                    message: "Thử đổi bộ lọc hoặc từ khóa tìm kiếm.",
                    actionTitle: viewModel.isFiltering ? "Đặt lại" : nil,
                    action: viewModel.isFiltering ? { viewModel.resetFilters() } : nil
                )
                .frame(minHeight: 320)
            }
            .accessibilityIdentifier("members.filter-empty")
        } else {
            CHCard {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.filteredMembers.enumerated()), id: \.element.id) { index, member in
                        Button {
                            viewModel.open(member: member, permissions: permissions)
                            openModule(.memberEdit(id: member.id.uuidString))
                        } label: {
                            MemberRow(member: member)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("members.row.\(member.id.uuidString)")

                        if index < viewModel.filteredMembers.count - 1 {
                            Rectangle()
                                .fill(CHColors.line)
                                .frame(height: 1)
                                .padding(.leading, 72)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier("members.list")
        }
    }

    private var departmentStats: some View {
        CHCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(MemberCopy.roleStatsHeading)
                    .font(CHTypography.caption.weight(.heavy))
                    .foregroundStyle(CHColors.muted)
                    .textCase(.uppercase)
                    .accessibilityIdentifier("members.stats.heading")

                HStack(spacing: 0) {
                    ForEach(viewModel.roleStats, id: \.0) { role, count in
                        VStack(spacing: 4) {
                            Text("\(count)")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(role.tint)
                            Text(role.compactLabel)
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(CHColors.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
        }
        .accessibilityIdentifier("members.stats")
    }
}

private struct MembersToolsPanel: View {
    @ObservedObject var viewModel: MembersViewModel

    var body: some View {
        CHCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Bộ lọc", systemImage: "line.3.horizontal.decrease.circle")
                        .font(CHTypography.label)
                        .foregroundStyle(CHColors.ink)
                    Spacer()
                    if viewModel.isFiltering {
                        Button("Đặt lại") {
                            viewModel.resetFilters()
                        }
                        .font(CHTypography.caption.weight(.bold))
                        .foregroundStyle(CHColors.purple)
                        .accessibilityIdentifier("members.filter.reset")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach([MemberRoleFilter.all, .admin, .creativeManager]) { filter in
                            MembersFilterChip(
                                title: filter.label,
                                isSelected: viewModel.roleFilter == filter,
                                identifier: "members.filter.role.\(filter.id)"
                            ) {
                                viewModel.roleFilter = filter
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach([MemberRoleFilter.contentCreator, .editor]) { filter in
                            MembersFilterChip(
                                title: filter.label,
                                isSelected: viewModel.roleFilter == filter,
                                identifier: "members.filter.role.\(filter.id)"
                            ) {
                                viewModel.roleFilter = filter
                            }
                        }
                    }
                }
                .accessibilityIdentifier("members.filter.role.rail")

                HStack(spacing: 8) {
                    ForEach(MemberStatusFilter.allCases) { filter in
                        MembersFilterChip(
                            title: filter.label,
                            isSelected: viewModel.statusFilter == filter,
                            identifier: "members.filter.status.\(filter.id)"
                        ) {
                            viewModel.statusFilter = filter
                        }
                    }
                }
                .accessibilityIdentifier("members.filter.status.rail")
            }
            .padding(14)
        }
    }
}

private struct MembersFilterChip: View {
    var title: String
    var isSelected: Bool
    var identifier: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isSelected ? .white : CHColors.ink)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? CHColors.purple : CHColors.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.clear : CHColors.line)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

private struct MemberRow: View {
    var member: MemberProfile

    var body: some View {
        HStack(spacing: 12) {
            CHAvatar(initials: member.initials, size: 44)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(member.titleName)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(CHColors.ink)
                        .lineLimit(1)
                    Text(member.role.label)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(member.role.tint)
                        .padding(.horizontal, 7)
                        .frame(height: 19)
                        .background(member.role.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                HStack(spacing: 5) {
                    Image(systemName: "envelope")
                        .font(.system(size: 11, weight: .semibold))
                    Text(member.email)
                        .lineLimit(1)
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(CHColors.muted)

                if member.isEditorMember {
                    Text(member.editorCode.isEmpty ? "Team editor" : "Editor · \(member.editorCode)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(CHColors.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Image(systemName: member.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(member.isActive ? CHColors.green : CHColors.orange)
                    .accessibilityIdentifier(member.isActive ? "members.status.active" : "members.status.inactive")
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CHColors.muted.opacity(0.55))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

struct MemberModuleView: View {
    @ObservedObject var viewModel: MembersViewModel
    var permissions: MemberPermissions
    var closeWithToast: (CHToastItem?) -> Void

    @State private var deleteConfirmation = ""
    @State private var resetPassword = ""
    @State private var resetConfirmation = ""
    @State private var resetInlineError: String?

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("member.module")

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    if let mode = viewModel.moduleMode {
                        switch mode {
                        case .detail(let member):
                            MemberReadonlyDetail(member: member)
                        case .create, .edit:
                            formBody(mode: mode)
                        }
                    }
                }
                .padding(.horizontal, CHSpacing.screen)
                .padding(.top, 14)
                .padding(.bottom, 126)
            }
            .safeAreaInset(edge: .bottom) {
                if isEditable {
                    actionBar
                        .opacity(isBlockingOverlayPresented ? 0 : 1)
                        .allowsHitTesting(!isBlockingOverlayPresented)
                }
            }

            if let pendingDelete = viewModel.pendingDelete {
                MemberDeleteConfirmation(
                    member: pendingDelete,
                    confirmation: $deleteConfirmation,
                    isBusy: viewModel.isMutating,
                    cancel: {
                        viewModel.pendingDelete = nil
                        deleteConfirmation = ""
                    },
                    confirm: {
                        Task {
                            let toast = await viewModel.deletePending(permissions: permissions)
                            if toast != nil {
                                closeWithToast(toast)
                            }
                        }
                    }
                )
            }

            if let pendingReset = viewModel.pendingResetPassword {
                MemberResetPasswordSheet(
                    member: pendingReset,
                    password: $resetPassword,
                    confirmation: $resetConfirmation,
                    inlineError: $resetInlineError,
                    isBusy: viewModel.isMutating,
                    cancel: {
                        viewModel.pendingResetPassword = nil
                        resetPassword = ""
                        resetConfirmation = ""
                        resetInlineError = nil
                    },
                    confirm: {
                        guard resetPassword == resetConfirmation else {
                            resetInlineError = "Mật khẩu xác nhận chưa khớp."
                            return
                        }
                        Task {
                            let toast = await viewModel.resetPassword(resetPassword, permissions: permissions)
                            if toast != nil {
                                resetPassword = ""
                                resetConfirmation = ""
                                resetInlineError = nil
                            }
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isEditable: Bool {
        switch viewModel.moduleMode {
        case .create, .edit:
            true
        case .detail, .none:
            false
        }
    }

    private var isBlockingOverlayPresented: Bool {
        viewModel.pendingDelete != nil || viewModel.pendingResetPassword != nil
    }

    private func formBody(mode: MemberModuleMode) -> some View {
        VStack(spacing: 14) {
            if case .edit(let member) = mode {
                MemberIdentityBanner(member: member)
            }

            MemberFormSection(title: "Tài khoản") {
                MemberTextField(title: "Họ tên", text: $viewModel.draft.fullName, identifier: "member.form.full-name")
                MemberTextField(title: "Tên hiển thị", text: $viewModel.draft.displayName, identifier: "member.form.display-name")
                MemberTextField(title: "Email", text: $viewModel.draft.email, keyboard: .emailAddress, identifier: "member.form.email")
                if case .create = mode {
                    MemberTextField(title: "Mật khẩu tạm", text: $viewModel.draft.password, isSecure: true, identifier: "member.form.password")
                } else {
                    MemberTextField(title: "Số điện thoại", text: $viewModel.draft.phone, keyboard: .phonePad, identifier: "member.form.phone")
                }
            }

            MemberFormSection(title: "Vai trò & bộ phận") {
                MemberPickerRow(title: "Vai trò", value: $viewModel.draft.role, values: MemberRole.allCases, identifier: "member.form.role")
                MemberTextField(title: "Bộ phận", text: $viewModel.draft.department, identifier: "member.form.department")
                Toggle("Đang hoạt động", isOn: $viewModel.draft.isActive)
                    .font(CHTypography.label)
                    .foregroundStyle(CHColors.ink)
                    .tint(CHColors.purple)
                    .accessibilityIdentifier("member.form.active")
            }

            MemberFormSection(title: "Thành viên editor") {
                Toggle("Tham gia team editor", isOn: $viewModel.draft.isEditorMember)
                    .font(CHTypography.label)
                    .foregroundStyle(CHColors.ink)
                    .tint(CHColors.purple)
                    .accessibilityIdentifier("member.form.editor-member")
                if viewModel.draft.isEditorMember {
                    MemberTextField(title: "Editor Code", text: $viewModel.draft.editorCode, identifier: "member.form.editor-code")
                }
                MemberTextField(title: "Crew Key cũ", text: $viewModel.draft.crewKey, identifier: "member.form.crew-key")
            }

            MemberFormSection(title: "Quyền sử dụng") {
                MemberPickerRow(title: "Chế độ quyền", value: $viewModel.draft.permissionMode, values: MemberPermissionMode.allCases, identifier: "member.form.permission-mode")
                Text("\(viewModel.draft.permissionMode.label) · \(MemberCopy.permissionSummarySuffix)")
                    .font(CHTypography.caption)
                    .foregroundStyle(CHColors.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("member.form.permission-summary")
            }

            if case .edit(let member) = mode, permissions.canManage {
                MemberFormSection(title: "Nâng cao") {
                    Button {
                        viewModel.pendingResetPassword = member
                    } label: {
                        Label("Reset mật khẩu", systemImage: "key")
                    }
                    .buttonStyle(CHSecondaryButtonStyle())
                    .accessibilityIdentifier("member.reset-password")

                    if member.canDelete(relativeTo: permissions) {
                        Button {
                            deleteConfirmation = ""
                            viewModel.pendingDelete = member
                        } label: {
                            Label("Xóa tài khoản", systemImage: "trash")
                                .foregroundStyle(CHColors.red)
                        }
                        .buttonStyle(CHSecondaryButtonStyle())
                        .accessibilityIdentifier("member.delete")
                    }
                }
            }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("member.action-bar")

            if let mutationError = viewModel.mutationError {
                Text(mutationError)
                    .font(CHTypography.caption.weight(.bold))
                    .foregroundStyle(CHColors.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("member.mutation-error")
            }

            HStack(spacing: 10) {
                Button {
                    closeWithToast(nil)
                } label: {
                    Text("Hủy")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CHSecondaryButtonStyle())
                .accessibilityIdentifier("member.cancel")

                Button {
                    Task {
                        let toast = await viewModel.save(permissions: permissions)
                        if toast != nil {
                            closeWithToast(toast)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(viewModel.isMutating ? "Đang lưu..." : "Lưu thay đổi")
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(CHPrimaryButtonStyle())
                .disabled(viewModel.isMutating)
                .accessibilityIdentifier("member.save")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, CHSpacing.screen)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(0.72))
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CHColors.line)
                .frame(height: 1)
        }
    }
}

private struct MemberReadonlyDetail: View {
    var member: MemberProfile

    var body: some View {
        VStack(spacing: 14) {
            MemberIdentityBanner(member: member)
            MemberPassiveSection(title: "Tài khoản", rows: [
                ("Họ tên", member.fullName),
                ("Tên hiển thị", member.displayName),
                ("Email", member.email),
                ("Số điện thoại", member.phone.nonEmptyMember ?? "-")
            ])
            MemberPassiveSection(title: "Vai trò & trạng thái", rows: [
                ("Vai trò", member.role.label),
                ("Bộ phận", member.department),
                ("Trạng thái", member.isActive ? "Đang hoạt động" : "Tạm khóa"),
                ("Quyền sử dụng", member.permissionMode.label)
            ])
            MemberPassiveSection(title: "Editor identity", rows: [
                ("Team editor", member.isEditorMember ? "Có tham gia" : "Không"),
                ("Editor Code", member.editorCode.nonEmptyMember ?? "-"),
                ("Crew Key cũ", member.crewKey.nonEmptyMember ?? "-")
            ])
        }
        .accessibilityIdentifier("member.readonly")
    }
}

private struct MemberIdentityBanner: View {
    var member: MemberProfile

    var body: some View {
        CHCard {
            HStack(spacing: 14) {
                CHAvatar(initials: member.initials, size: 58)
                VStack(alignment: .leading, spacing: 5) {
                    Text(member.titleName)
                        .font(CHTypography.headline)
                        .foregroundStyle(CHColors.ink)
                    Text(member.email)
                        .font(CHTypography.caption.weight(.semibold))
                        .foregroundStyle(CHColors.muted)
                    HStack(spacing: 6) {
                        Text(member.role.label)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(member.role.tint)
                        Text(member.isActive ? "Đang hoạt động" : "Tạm khóa")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(member.isActive ? CHColors.green : CHColors.orange)
                    }
                }
                Spacer()
            }
            .padding(16)
        }
        .accessibilityIdentifier("member.identity")
    }
}

private struct MemberFormSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        CHCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(CHTypography.label)
                    .foregroundStyle(CHColors.ink)
                content()
            }
            .padding(16)
        }
    }
}

private struct MemberTextField: View {
    var title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var isSecure = false
    var identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(CHTypography.caption.weight(.bold))
                .foregroundStyle(CHColors.muted)
            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .font(CHTypography.body)
            .foregroundStyle(CHColors.ink)
            .tint(CHColors.purple)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(keyboard)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(CHColors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CHColors.line))
            .accessibilityIdentifier(identifier)
        }
    }
}

private struct MemberPickerRow<Value: CaseIterable & Identifiable & Equatable>: View where Value.AllCases: RandomAccessCollection {
    var title: String
    @Binding var value: Value
    var values: Value.AllCases
    var identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(CHTypography.caption.weight(.bold))
                .foregroundStyle(CHColors.muted)
            Menu {
                ForEach(values) { item in
                    Button(label(for: item)) {
                        value = item
                    }
                }
            } label: {
                HStack {
                    Text(label(for: value))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                }
                .font(CHTypography.body.weight(.bold))
                .foregroundStyle(CHColors.ink)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(CHColors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CHColors.line))
            }
            .accessibilityIdentifier(identifier)
        }
    }

    private func label(for value: Value) -> String {
        switch value {
        case let role as MemberRole:
            role.label
        case let mode as MemberPermissionMode:
            mode.label
        default:
            "\(value.id)"
        }
    }
}

private struct MemberPassiveSection: View {
    var title: String
    var rows: [(String, String)]

    var body: some View {
        CHCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(CHTypography.label)
                    .foregroundStyle(CHColors.ink)
                ForEach(rows, id: \.0) { label, value in
                    HStack(alignment: .firstTextBaseline) {
                        Text(label)
                            .font(CHTypography.caption.weight(.bold))
                            .foregroundStyle(CHColors.muted)
                        Spacer()
                        Text(value)
                            .font(CHTypography.caption.weight(.heavy))
                            .foregroundStyle(CHColors.ink)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding(16)
        }
    }
}

private struct MemberDeleteConfirmation: View {
    var member: MemberProfile
    @Binding var confirmation: String
    var isBusy: Bool
    var cancel: () -> Void
    var confirm: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("member.delete.confirm")

            Color.black.opacity(0.24)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Label("Xóa vĩnh viễn tài khoản?", systemImage: "exclamationmark.triangle.fill")
                    .font(CHTypography.headline)
                    .foregroundStyle(CHColors.red)
                    .lineLimit(2)
                Text("\(MemberCopy.deleteConsequence) Thao tác này không thể hoàn tác.")
                    .font(CHTypography.caption)
                    .foregroundStyle(CHColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("member.delete.copy")
                MemberTextField(title: "Nhập email để xác nhận", text: $confirmation, keyboard: .emailAddress, identifier: "member.delete.confirm-email")
                HStack(spacing: 10) {
                    Button(action: cancel) {
                        Text("Hủy")
                            .frame(maxWidth: .infinity)
                    }
                        .buttonStyle(CHSecondaryButtonStyle())
                        .accessibilityIdentifier("member.delete.cancel")
                    Button {
                        confirm()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text(isBusy ? "Đang xóa..." : "Xóa vĩnh viễn")
                                .lineLimit(1)
                                .minimumScaleFactor(0.86)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CHPrimaryButtonStyle())
                    .disabled(isBusy || confirmation.normalizedMemberEmail != member.email.normalizedMemberEmail)
                }
            }
            .padding(18)
            .frame(maxWidth: 348)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(CHColors.cardSolid)
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.82), lineWidth: 1))
                    .shadow(color: CHShadow.softColor, radius: 20, y: 14)
            )
            .padding(.horizontal, CHSpacing.screen)
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MemberResetPasswordSheet: View {
    var member: MemberProfile
    @Binding var password: String
    @Binding var confirmation: String
    @Binding var inlineError: String?
    var isBusy: Bool
    var cancel: () -> Void
    var confirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
            CHCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Đặt mật khẩu mới", systemImage: "key.fill")
                        .font(CHTypography.headline)
                        .foregroundStyle(CHColors.ink)
                    Text(member.titleName)
                        .font(CHTypography.caption.weight(.bold))
                        .foregroundStyle(CHColors.muted)
                    MemberTextField(title: "Mật khẩu mới", text: $password, isSecure: true, identifier: "member.reset.password")
                    MemberTextField(title: "Nhập lại mật khẩu", text: $confirmation, isSecure: true, identifier: "member.reset.confirm")
                    if let inlineError {
                        Text(inlineError)
                            .font(CHTypography.caption.weight(.bold))
                            .foregroundStyle(CHColors.red)
                    }
                    HStack {
                        Button("Hủy", action: cancel)
                            .buttonStyle(CHSecondaryButtonStyle())
                            .accessibilityIdentifier("member.reset.cancel")
                        Button {
                            confirm()
                        } label: {
                            Label(isBusy ? "Đang reset..." : "Cập nhật mật khẩu", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(CHPrimaryButtonStyle())
                        .disabled(isBusy || password.isEmpty || confirmation.isEmpty)
                    }
                }
                .padding(18)
            }
            .padding(CHSpacing.screen)
        }
        .accessibilityIdentifier("member.reset.confirm")
    }
}

private extension String {
    var trimmedMember: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmptyMember: String? {
        let value = trimmedMember
        return value.isEmpty ? nil : value
    }

    var nonEmptyMember: String? {
        nilIfEmptyMember
    }

    var normalizedMemberEmail: String {
        trimmedMember.lowercased()
    }
}

private extension Optional where Wrapped == String {
    var nonEmptyMember: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
