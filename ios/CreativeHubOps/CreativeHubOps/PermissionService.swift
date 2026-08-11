import Foundation

enum PermissionService {
    static func effectivePermissions(role: AppRole, override: UserPermissionOverride?) -> Set<Permission> {
        var permissions = rolePermissions(role)
        guard let override, override.accessMode != .roleDefault else {
            return permissions
        }

        if override.accessMode == .viewOnly {
            setVideoTaskEditPermissions(&permissions, enabled: false)
            setShootEditPermissions(&permissions, enabled: false)
            setContentPlanContentPermissions(&permissions, enabled: false)
            permissions.remove(.contentPlanAssign)
            setUserManagePermissions(&permissions, enabled: false)
            permissions.remove(.profileEditSelf)
            return permissions
        }

        let flags = override.flags

        set(&permissions, .dashboardView, enabled: flags[.dashboardView] == true)

        set(&permissions, .shootsView, enabled: flags[.calendarView] == true)
        setShootEditPermissions(&permissions, enabled: flags[.calendarEdit] == true)
        if permissions.contains(.shootsCreate) || permissions.contains(.shootsUpdate) || permissions.contains(.shootsDelete) {
            permissions.insert(.shootsView)
        }

        set(&permissions, .videoTasksView, enabled: flags[.tasksView] == true)
        setVideoTaskEditPermissions(&permissions, enabled: flags[.tasksEdit] == true)
        if permissions.contains(.videoTasksCreate) || permissions.contains(.videoTasksUpdate) || permissions.contains(.videoTasksDelete) {
            permissions.insert(.videoTasksView)
        }

        set(&permissions, .contentPlanView, enabled: flags[.contentPlanView] == true)
        setContentPlanContentPermissions(&permissions, enabled: flags[.contentPlanEditContent] == true)
        set(&permissions, .contentPlanAssign, enabled: flags[.contentPlanAssignEditor] == true)
        if permissions.contains(.contentPlanCreate) ||
            permissions.contains(.contentPlanUpdate) ||
            permissions.contains(.contentPlanDelete) ||
            permissions.contains(.contentPlanAssign) {
            permissions.insert(.contentPlanView)
        }

        setUserManagePermissions(&permissions, enabled: role == .admin)
        set(&permissions, .profileEditSelf, enabled: flags[.profileEditSelf] != false)

        return permissions
    }

    static func canManageUsers(profile: CurrentUserProfile?) -> Bool {
        guard let profile else { return false }
        return profile.can(.userManagementView) && profile.can(.userManagementCreate) && profile.can(.userManagementUpdate)
    }

    static func canEditContentPlanField(profile: CurrentUserProfile?, field: String) -> Bool {
        guard let profile else { return false }
        let canEditContent = profile.can(.contentPlanUpdate)
        let canAssignEditor = profile.can(.contentPlanAssign)
        if field == "editor_id" {
            return canAssignEditor || (profile.role == .admin && canEditContent)
        }
        return canEditContent
    }

    private static func rolePermissions(_ role: AppRole) -> Set<Permission> {
        switch role {
        case .admin:
            return Set(Permission.allCases)
        case .creativeManager:
            return [
                .dashboardView,
                .videoTasksView, .videoTasksCreate, .videoTasksUpdate, .videoTasksDelete,
                .shootsView, .shootsCreate, .shootsUpdate, .shootsDelete,
                .contentPlanView, .contentPlanAssign,
                .profileEditSelf,
            ]
        case .contentCreator:
            return [
                .shootsView, .shootsCreate, .shootsUpdate, .shootsDelete,
                .contentPlanView, .contentPlanCreate, .contentPlanUpdate, .contentPlanDelete,
                .profileEditSelf,
            ]
        case .editor:
            return [
                .dashboardView,
                .videoTasksView, .videoTasksCreate, .videoTasksUpdate, .videoTasksDelete,
                .shootsView,
                .contentPlanView,
                .profileEditSelf,
            ]
        }
    }

    private static func set(_ permissions: inout Set<Permission>, _ permission: Permission, enabled: Bool) {
        if enabled {
            permissions.insert(permission)
        } else {
            permissions.remove(permission)
        }
    }

    private static func setVideoTaskEditPermissions(_ permissions: inout Set<Permission>, enabled: Bool) {
        set(&permissions, .videoTasksCreate, enabled: enabled)
        set(&permissions, .videoTasksUpdate, enabled: enabled)
        set(&permissions, .videoTasksDelete, enabled: enabled)
    }

    private static func setShootEditPermissions(_ permissions: inout Set<Permission>, enabled: Bool) {
        set(&permissions, .shootsCreate, enabled: enabled)
        set(&permissions, .shootsUpdate, enabled: enabled)
        set(&permissions, .shootsDelete, enabled: enabled)
    }

    private static func setContentPlanContentPermissions(_ permissions: inout Set<Permission>, enabled: Bool) {
        set(&permissions, .contentPlanCreate, enabled: enabled)
        set(&permissions, .contentPlanUpdate, enabled: enabled)
        set(&permissions, .contentPlanDelete, enabled: enabled)
    }

    private static func setUserManagePermissions(_ permissions: inout Set<Permission>, enabled: Bool) {
        set(&permissions, .userManagementView, enabled: enabled)
        set(&permissions, .userManagementCreate, enabled: enabled)
        set(&permissions, .userManagementUpdate, enabled: enabled)
    }
}

