import Foundation
import Network

enum AuthenticationState: Equatable, Sendable {
    case checkingSession
    case signedOut
    case signingIn
    case authenticated
    case empty
    case offline
    case loadError
    case forbidden
    case sessionExpired
}

struct CurrentUserSummary: Equatable, Sendable {
    var displayName: String
    var email: String
    var avatarURL: URL?

    static let preview = CurrentUserSummary(
        displayName: "Creative Team",
        email: "team@creativehub.local",
        avatarURL: nil
    )

    static let empty = CurrentUserSummary(displayName: "", email: "", avatarURL: nil)
}

struct AuthenticatedUser: Equatable, Sendable {
    var id: UUID
    var email: String?
    var metadata: [String: String]
}

struct AuthProfileSummary: Equatable, Sendable {
    var id: UUID
    var email: String
    var fullName: String
    var displayName: String
    var avatarURL: URL?
    var department: String
    var role: CreativeHubRole
    var rawRole: String?
}

enum CreativeHubRole: String, Equatable, Sendable {
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
}

enum PermissionAccessMode: String, Equatable, Sendable {
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
}

struct UserPermissionOverride: Equatable, Sendable {
    var accessMode: PermissionAccessMode
    var flags: [String: Bool?]

    static let roleDefault = UserPermissionOverride(accessMode: .roleDefault, flags: [:])
}

struct AuthBootstrapResult: Equatable, Sendable {
    var profile: AuthProfileSummary
    var permissionOverride: UserPermissionOverride
}

enum CreativeHubPermission: String, CaseIterable, Sendable {
    case dashboardView = "dashboard:view"
    case taskPlannerView = "task_planner:view"
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

struct PasswordRecoveryInfo: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var message: String

    static let deferred = PasswordRecoveryInfo(
        title: "Khôi phục mật khẩu",
        message: "Tính năng khôi phục mật khẩu chưa được cấu hình trên hệ thống. Vui lòng liên hệ quản trị viên để được hỗ trợ."
    )
}

enum AuthServiceError: Error, Equatable, Sendable {
    case configurationMissing
    case noSession
    case invalidCredentials
    case emailNotConfirmed
    case rateLimited
    case sessionExpired
    case forbidden
    case passwordResetUnavailable
    case backend(String)
}

protocol AuthServicing: Sendable {
    var isConfigured: Bool { get }
    func restoredSessionUser() async throws -> AuthenticatedUser?
    func signIn(email: String, password: String) async throws -> AuthenticatedUser
    func bootstrap(user: AuthenticatedUser) async throws -> AuthBootstrapResult
    func signOut() async throws
    func requestPasswordReset(email: String) async throws
}

protocol NetworkMonitoring {
    var isConnected: Bool { get }
}

final class SystemNetworkMonitor: NetworkMonitoring, @unchecked Sendable {
    static let shared = SystemNetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "creativehub.network-monitor")
    private let lock = NSLock()
    private var connected = true

    var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return connected
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.setConnected(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    private func setConnected(_ nextValue: Bool) {
        lock.lock()
        connected = nextValue
        lock.unlock()
    }
}

struct StaticNetworkMonitor: NetworkMonitoring {
    var isConnected: Bool
}

@MainActor
final class AppState: ObservableObject {
    static let invalidCredentialsMessage = "Email hoặc mật khẩu chưa chính xác."

    @Published var authentication: AuthenticationState = .checkingSession
    @Published var currentUser: CurrentUserSummary = .empty
    @Published var loginEmail = ""
    @Published var loginPassword = ""
    @Published var loginError: String?
    @Published var isLoginSubmitting = false
    @Published var toast: CHToastItem?
    @Published var passwordRecoveryInfo: PasswordRecoveryInfo?
    @Published private(set) var currentRole: CreativeHubRole = .editor
    @Published private(set) var permissionOverride: UserPermissionOverride = .roleDefault
    @Published private(set) var currentProfileID: UUID?

    let authService: AuthServicing
    let networkMonitor: NetworkMonitoring

    init(
        authService: AuthServicing = SupabaseService.shared,
        networkMonitor: NetworkMonitoring = SystemNetworkMonitor.shared
    ) {
        self.authService = authService
        self.networkMonitor = networkMonitor
    }

    func start() async {
        if applyLaunchStateOverrideIfNeeded() {
            return
        }

        await bootstrapFromStoredSession()
    }

    func setAuthentication(_ nextState: AuthenticationState) {
        authentication = nextState
    }

    func signIn() async {
        loginError = nil
        let email = loginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = loginPassword

        guard !email.isEmpty, !password.isEmpty else {
            loginError = "Vui lòng nhập email và mật khẩu."
            return
        }

        #if DEBUG
        if ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE11_FIX02_LOGIN_FIXTURE"] == "1" {
            applyAuthenticatedShellFixture(environment: ProcessInfo.processInfo.environment)
            return
        }
        #endif

        guard networkMonitor.isConnected else {
            authentication = .offline
            return
        }

        guard authService.isConfigured else {
            authentication = .loadError
            return
        }

        isLoginSubmitting = true
        authentication = .signingIn
        defer { isLoginSubmitting = false }

        do {
            let user = try await authService.signIn(email: email, password: password)
            try await applyAuthenticatedUser(user)
        } catch {
            handleLoginError(error)
        }
    }

    func retryBootstrap() {
        Task {
            await bootstrapFromStoredSession()
        }
    }

    func returnToLogin() {
        Task {
            _ = await signOutAndReturnToLogin()
        }
    }

    func signOutAndReturnToLogin() async -> Bool {
        do {
            try await authService.signOut()
            clearSensitiveSessionState()
            authentication = .signedOut
            return true
        } catch {
            return false
        }
    }

    func requestPasswordReset() {
        passwordRecoveryInfo = .deferred
    }

    func dismissPasswordRecoveryInfo() {
        passwordRecoveryInfo = nil
    }

    func showToast(_ item: CHToastItem) {
        toast = item
    }

    func can(_ permission: CreativeHubPermission) -> Bool {
        effectivePermissions[permission] == true
    }

    func dismissToast() {
        toast = nil
    }

    func updateCurrentUserSummary(displayName: String, email: String, avatarURL: URL?) {
        currentUser = CurrentUserSummary(displayName: displayName, email: email, avatarURL: avatarURL)
    }

    private func bootstrapFromStoredSession() async {
        loginError = nil
        authentication = .checkingSession

        guard networkMonitor.isConnected else {
            authentication = .offline
            return
        }

        guard authService.isConfigured else {
            authentication = .loadError
            return
        }

        do {
            guard let user = try await authService.restoredSessionUser() else {
                clearSensitiveSessionState()
                authentication = .signedOut
                return
            }
            try await applyAuthenticatedUser(user)
        } catch {
            handleBootstrapError(error)
        }
    }

    private func applyAuthenticatedUser(_ user: AuthenticatedUser) async throws {
        let result = try await authService.bootstrap(user: user)
        currentUser = CurrentUserSummary(
            displayName: result.profile.displayName,
            email: result.profile.email,
            avatarURL: result.profile.avatarURL
        )
        currentProfileID = result.profile.id
        currentRole = result.profile.role
        permissionOverride = result.permissionOverride
        loginPassword = ""
        authentication = .authenticated
    }

    private func handleLoginError(_ error: Error) {
        if let serviceError = error as? AuthServiceError {
            switch serviceError {
            case .invalidCredentials:
                authentication = .signedOut
                loginError = Self.invalidCredentialsMessage
            case .emailNotConfirmed:
                authentication = .signedOut
                loginError = "Email chưa được xác nhận. Vui lòng kiểm tra hộp thư."
            case .rateLimited:
                authentication = .signedOut
                loginError = "Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút."
            case .forbidden:
                clearSensitiveSessionState()
                authentication = .forbidden
            case .sessionExpired, .noSession:
                clearSensitiveSessionState()
                authentication = .sessionExpired
            case .configurationMissing, .backend:
                authentication = .loadError
            case .passwordResetUnavailable:
                authentication = .signedOut
                loginError = "Chưa có cấu hình đặt lại mật khẩu trên iOS."
            }
        } else {
            authentication = .loadError
        }
    }

    private func handleBootstrapError(_ error: Error) {
        if let serviceError = error as? AuthServiceError {
            switch serviceError {
            case .noSession:
                clearSensitiveSessionState()
                authentication = .signedOut
            case .sessionExpired:
                clearSensitiveSessionState()
                authentication = .sessionExpired
            case .forbidden:
                clearSensitiveSessionState()
                authentication = .forbidden
            case .configurationMissing, .backend, .invalidCredentials, .emailNotConfirmed, .rateLimited, .passwordResetUnavailable:
                authentication = .loadError
            }
        } else {
            authentication = .loadError
        }
    }

    private func clearSensitiveSessionState() {
        currentUser = .empty
        currentProfileID = nil
        currentRole = .editor
        permissionOverride = .roleDefault
        loginPassword = ""
    }

    private func applyLaunchStateOverrideIfNeeded() -> Bool {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard let value = environment["CREATIVEHUB_PHASE2_STATE"] else {
            return false
        }

        switch value {
        case "login":
            authentication = .signedOut
        case "login-invalid":
            authentication = .signedOut
            loginEmail = "dqdatt@gmail.com"
            loginError = Self.invalidCredentialsMessage
        case "loading":
            authentication = .checkingSession
        case "empty":
            authentication = .empty
        case "load-error":
            authentication = .loadError
        case "offline":
            authentication = .offline
        case "forbidden":
            authentication = .forbidden
        case "session-expired":
            authentication = .sessionExpired
        case "authenticated-shell":
            applyAuthenticatedShellFixture(environment: environment)
        default:
            return false
        }
        return true
        #else
        return false
        #endif
    }

    #if DEBUG
    private func applyAuthenticatedShellFixture(environment: [String: String]) {
        currentUser = CurrentUserSummary(displayName: "QA User", email: "qa@example.test", avatarURL: nil)
        currentProfileID = environment["CREATIVEHUB_PHASE11_PROFILE_ID"]
            .flatMap(UUID.init(uuidString:))
            ?? UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        currentRole = .admin
        permissionOverride = phase5DebugPermissionOverride()
        loginPassword = ""
        authentication = .authenticated
    }
    #endif

    private var effectivePermissions: [CreativeHubPermission: Bool] {
        var permissions = Self.rolePermissions(for: currentRole)

        switch permissionOverride.accessMode {
        case .roleDefault:
            return permissions
        case .viewOnly:
            setVideoTaskEditPermissions(&permissions, enabled: false)
            setShootEditPermissions(&permissions, enabled: false)
            setContentPlanContentPermissions(&permissions, enabled: false)
            permissions[.contentPlanAssign] = false
            setUserManagePermissions(&permissions, enabled: false)
            permissions[.profileEditSelf] = false
            permissions[.taskPlannerView] = currentRole == .admin
            return permissions
        case .custom:
            let flags = permissionOverride.flags
            permissions[.dashboardView] = flags["dashboard_view"] == true
            permissions[.taskPlannerView] = currentRole == .admin
            permissions[.shootsView] = flags["calendar_view"] == true
            setShootEditPermissions(&permissions, enabled: flags["calendar_edit"] == true)
            if permissions[.shootsCreate] == true || permissions[.shootsUpdate] == true || permissions[.shootsDelete] == true {
                permissions[.shootsView] = true
            }
            permissions[.videoTasksView] = flags["tasks_view"] == true
            setVideoTaskEditPermissions(&permissions, enabled: flags["tasks_edit"] == true)
            if permissions[.videoTasksCreate] == true || permissions[.videoTasksUpdate] == true || permissions[.videoTasksDelete] == true {
                permissions[.videoTasksView] = true
            }
            permissions[.contentPlanView] = flags["content_plan_view"] == true
            setContentPlanContentPermissions(&permissions, enabled: flags["content_plan_edit_content"] == true)
            permissions[.contentPlanAssign] = flags["content_plan_assign_editor"] == true
            if permissions[.contentPlanCreate] == true || permissions[.contentPlanUpdate] == true || permissions[.contentPlanDelete] == true || permissions[.contentPlanAssign] == true {
                permissions[.contentPlanView] = true
            }
            setUserManagePermissions(&permissions, enabled: currentRole == .admin)
            permissions[.profileEditSelf] = flags["profile_edit_self"] != false
            return permissions
        }
    }

    private static func rolePermissions(for role: CreativeHubRole) -> [CreativeHubPermission: Bool] {
        var permissions = Dictionary(uniqueKeysWithValues: CreativeHubPermission.allCases.map { ($0, false) })
        let enabled: [CreativeHubPermission]
        switch role {
        case .admin:
            enabled = CreativeHubPermission.allCases
        case .creativeManager:
            enabled = [
                .dashboardView,
                .videoTasksView, .videoTasksCreate, .videoTasksUpdate, .videoTasksDelete,
                .shootsView, .shootsCreate, .shootsUpdate, .shootsDelete,
                .contentPlanView, .contentPlanAssign,
                .profileEditSelf
            ]
        case .contentCreator:
            enabled = [
                .shootsView, .shootsCreate, .shootsUpdate, .shootsDelete,
                .contentPlanView, .contentPlanCreate, .contentPlanUpdate, .contentPlanDelete,
                .profileEditSelf
            ]
        case .editor:
            enabled = [
                .dashboardView,
                .videoTasksView, .videoTasksCreate, .videoTasksUpdate, .videoTasksDelete,
                .shootsView,
                .contentPlanView,
                .profileEditSelf
            ]
        }
        enabled.forEach { permissions[$0] = true }
        return permissions
    }

    private func setVideoTaskEditPermissions(_ permissions: inout [CreativeHubPermission: Bool], enabled: Bool) {
        permissions[.videoTasksCreate] = enabled
        permissions[.videoTasksUpdate] = enabled
        permissions[.videoTasksDelete] = enabled
    }

    private func setShootEditPermissions(_ permissions: inout [CreativeHubPermission: Bool], enabled: Bool) {
        permissions[.shootsCreate] = enabled
        permissions[.shootsUpdate] = enabled
        permissions[.shootsDelete] = enabled
    }

    private func setContentPlanContentPermissions(_ permissions: inout [CreativeHubPermission: Bool], enabled: Bool) {
        permissions[.contentPlanCreate] = enabled
        permissions[.contentPlanUpdate] = enabled
        permissions[.contentPlanDelete] = enabled
    }

    private func setUserManagePermissions(_ permissions: inout [CreativeHubPermission: Bool], enabled: Bool) {
        permissions[.userManagementView] = enabled
        permissions[.userManagementCreate] = enabled
        permissions[.userManagementUpdate] = enabled
    }

    private func phase5DebugPermissionOverride() -> UserPermissionOverride {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE6_VIDEO_TASKS_PERMISSION"] {
        case "readonly":
            return UserPermissionOverride(accessMode: .custom, flags: [
                "dashboard_view": true,
                "calendar_view": true,
                "calendar_edit": true,
                "tasks_view": true,
                "tasks_edit": false,
                "content_plan_view": true,
                "content_plan_edit_content": false,
                "content_plan_assign_editor": false,
                "users_manage": false,
                "profile_edit_self": true
            ])
        case "create-only":
            return UserPermissionOverride(accessMode: .custom, flags: [
                "dashboard_view": true,
                "calendar_view": true,
                "calendar_edit": true,
                "tasks_view": true,
                "tasks_edit": true,
                "content_plan_view": true,
                "content_plan_edit_content": false,
                "content_plan_assign_editor": false,
                "users_manage": false,
                "profile_edit_self": true
            ])
        default:
            break
        }
        switch ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE5_CALENDAR_PERMISSION"] {
        case "readonly":
            return UserPermissionOverride(accessMode: .viewOnly, flags: [:])
        default:
            return .roleDefault
        }
        #else
        return .roleDefault
        #endif
    }
}
