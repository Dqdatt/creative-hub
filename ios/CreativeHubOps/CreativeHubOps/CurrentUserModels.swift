import Foundation

enum AppRole: String, Codable, CaseIterable, Identifiable {
    case admin
    case creativeManager = "creative_manager"
    case contentCreator = "content_creator"
    case editor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .admin: "Quản trị viên"
        case .creativeManager: "Creative Manager"
        case .contentCreator: "Content Creator"
        case .editor: "Editor"
        }
    }

    static func normalize(_ rawValue: String?) -> AppRole {
        switch rawValue {
        case "admin": .admin
        case "creative_manager", "team_lead": .creativeManager
        case "content_creator": .contentCreator
        case "editor": .editor
        default: .editor
        }
    }
}

enum Permission: String, CaseIterable, Hashable {
    case dashboardView = "dashboard:view"
    case videoTasksView = "video_tasks:view"
    case videoTasksCreate = "video_tasks:create"
    case videoTasksUpdate = "video_tasks:update"
    case videoTasksDelete = "video_tasks:delete"
    case shootsView = "shoots:view"
    case shootsCreate = "shoots:create"
    case shootsUpdate = "shoots:update"
    case shootsDelete = "shoots:delete"
    case contentPlanView = "content_plan:view"
    case contentPlanCreate = "content_plan:create"
    case contentPlanUpdate = "content_plan:update"
    case contentPlanAssign = "content_plan:assign"
    case contentPlanDelete = "content_plan:delete"
    case userManagementView = "user_management:view"
    case userManagementCreate = "user_management:create"
    case userManagementUpdate = "user_management:update"
    case profileEditSelf = "profile:edit_self"
}

enum PermissionAccessMode: String, Codable, Equatable {
    case roleDefault = "role_default"
    case viewOnly = "view_only"
    case custom
}

enum PermissionOverrideKey: String, CaseIterable, Codable {
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

struct UserPermissionOverride: Equatable {
    static let roleDefault = UserPermissionOverride(accessMode: .roleDefault, flags: [:])

    let accessMode: PermissionAccessMode
    let flags: [PermissionOverrideKey: Bool?]
}

struct CurrentUserProfile: Equatable, Identifiable {
    let id: UUID
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
    let permissions: Set<Permission>

    var initials: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "Đ"
    }

    var roleLabel: String {
        role.label
    }

    func can(_ permission: Permission) -> Bool {
        permissions.contains(permission)
    }
}

struct ProfileFormData: Equatable {
    var fullName = ""
    var displayName = ""
    var phone = ""
    var department = "Team Marketing"
}
