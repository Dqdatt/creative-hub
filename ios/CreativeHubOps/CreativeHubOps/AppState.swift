import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case dashboard
    case tasks
    case calendar
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Tổng quan"
        case .tasks: "Video"
        case .calendar: "Lịch quay"
        case .profile: "Cá nhân"
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .tasks: "video"
        case .calendar: "calendar"
        case .profile: "person"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: MainTab = .dashboard
    @Published var isAuthenticated = false
    @Published var authSession: AuthSessionSnapshot?
    @Published var currentProfile: CurrentUserProfile?
    @Published var isDarkMode = false
    @Published var activeSheet: AppSheet?
    @Published var path: [AppRoute] = []

    var preferredColorScheme: ColorScheme? {
        .light
    }

    func authenticate(with session: AuthSessionSnapshot, profile: CurrentUserProfile) {
        authSession = session
        currentProfile = profile
        isAuthenticated = true
    }

    func clearSession() {
        selectedTab = .dashboard
        authSession = nil
        currentProfile = nil
        activeSheet = nil
        path.removeAll()
        isAuthenticated = false
    }

    func can(_ permission: Permission) -> Bool {
        currentProfile?.can(permission) == true
    }
}

enum AppRoute: Hashable {
    case contentPlan
    case users
    case notifications
    case taskDetail(String)
    case shootDetail(String)
    case contentPlanDetail(String)
    case userDetail(String)
}

enum AppSheet: Identifiable {
    case quickCreateTask
    case taskEdit
    case linkedTaskAccept
    case linkedTaskExecution
    case shootCreate
    case shootEdit
    case contentPlanCreate
    case contentPlanEdit
    case adminUserCreate
    case adminUserEdit
    case adminPasswordReset
    case profileEdit
    case passwordEdit

    var id: String {
        switch self {
        case .quickCreateTask: "quickCreateTask"
        case .taskEdit: "taskEdit"
        case .linkedTaskAccept: "linkedTaskAccept"
        case .linkedTaskExecution: "linkedTaskExecution"
        case .shootCreate: "shootCreate"
        case .shootEdit: "shootEdit"
        case .contentPlanCreate: "contentPlanCreate"
        case .contentPlanEdit: "contentPlanEdit"
        case .adminUserCreate: "adminUserCreate"
        case .adminUserEdit: "adminUserEdit"
        case .adminPasswordReset: "adminPasswordReset"
        case .profileEdit: "profileEdit"
        case .passwordEdit: "passwordEdit"
        }
    }
}
