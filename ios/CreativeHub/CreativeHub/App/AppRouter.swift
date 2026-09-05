import Foundation

enum MainDestination: String, CaseIterable, Identifiable {
    case overview
    case video
    case calendar
    case content
    case members

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Tổng quan"
        case .video: "Video"
        case .calendar: "Lịch quay"
        case .content: "Content"
        case .members: "Thành viên"
        }
    }

    var iconName: String {
        switch self {
        case .overview: "chart.pie.fill"
        case .video: "play.rectangle.fill"
        case .calendar: "calendar"
        case .content: "doc.text.fill"
        case .members: "person.2.fill"
        }
    }

    static let regularTabs: [MainDestination] = [.overview, .video, .content, .members]

    var topBarTitle: String {
        switch self {
        case .overview: title
        case .video: "Video tháng"
        case .calendar: "Lịch quay"
        case .content: "Content Plan"
        case .members: "Thành viên"
        }
    }

    var canRevealTools: Bool {
        self != .overview
    }

    var navigationAccessibilityIdentifier: String {
        "navbar.\(rawValue)"
    }
}

enum SecondaryDestination: Hashable, Identifiable {
    case notifications
    case profile

    var id: String {
        switch self {
        case .notifications: "notifications"
        case .profile: "profile"
        }
    }

    var title: String {
        switch self {
        case .notifications: "Thông báo"
        case .profile: "Hồ sơ"
        }
    }
}

enum ModuleDestination: Hashable, Identifiable {
    case phase3Harness(origin: MainDestination)
    case taskCreate
    case taskEdit(id: String)
    case shootCreate
    case shootEdit(id: String)
    case contentCreate
    case contentEdit(id: String)
    case memberCreate
    case memberEdit(id: String)
    case changeAvatar
    case changePassword
    case language
    case theme

    var id: String {
        switch self {
        case .phase3Harness(let origin): "phase3Harness-\(origin.rawValue)"
        case .taskCreate: "taskCreate"
        case .taskEdit(let id): "taskEdit-\(id)"
        case .shootCreate: "shootCreate"
        case .shootEdit(let id): "shootEdit-\(id)"
        case .contentCreate: "contentCreate"
        case .contentEdit(let id): "contentEdit-\(id)"
        case .memberCreate: "memberCreate"
        case .memberEdit(let id): "memberEdit-\(id)"
        case .changeAvatar: "changeAvatar"
        case .changePassword: "changePassword"
        case .language: "language"
        case .theme: "theme"
        }
    }

    var title: String {
        switch self {
        case .phase3Harness:
            "Module kiểm thử"
        case .taskCreate, .taskEdit:
            "Video"
        case .shootCreate, .shootEdit:
            "Lịch quay"
        case .contentCreate, .contentEdit:
            "Content Plan"
        case .memberCreate, .memberEdit:
            "Thành viên"
        case .changeAvatar:
            "Avatar"
        case .changePassword:
            "Đổi mật khẩu"
        case .language:
            "Ngôn ngữ"
        case .theme:
            "Theme"
        }
    }
}

enum AppRoute: Hashable, Identifiable {
    case secondary(SecondaryDestination)
    case module(ModuleDestination)

    var id: String {
        switch self {
        case .secondary(let destination): destination.id
        case .module(let destination): destination.id
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published private(set) var selectedMain: MainDestination = .overview
    @Published private(set) var path: [AppRoute] = []
    @Published private var revealedToolDestinations: Set<MainDestination> = []

    var activeSecondary: SecondaryDestination? {
        guard case .secondary(let destination) = path.last else { return nil }
        return destination
    }

    var activeModule: ModuleDestination? {
        guard case .module(let destination) = path.last else { return nil }
        return destination
    }

    var isBottomNavigationVisible: Bool {
        path.isEmpty
    }

    var isShowingAuthenticatedOverlay: Bool {
        !path.isEmpty
    }

    func selectMain(_ destination: MainDestination) {
        guard selectedMain != destination || !path.isEmpty else {
            return
        }
        selectedMain = destination
        path.removeAll()
    }

    func pushSecondary(_ destination: SecondaryDestination) {
        guard path.last != .secondary(destination) else {
            return
        }
        path = [.secondary(destination)]
    }

    func pushModule(_ destination: ModuleDestination) {
        guard path.last != .module(destination) else {
            return
        }
        path = [.module(destination)]
    }

    func pop() {
        _ = path.popLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    func resetToAuthenticatedRoot() {
        selectedMain = .overview
        path.removeAll()
        revealedToolDestinations.removeAll()
    }

    func resetForLogout() {
        resetToAuthenticatedRoot()
    }

    func toggleToolReveal(for destination: MainDestination? = nil) {
        let destination = destination ?? selectedMain
        guard destination.canRevealTools else {
            return
        }

        if revealedToolDestinations.contains(destination) {
            revealedToolDestinations.remove(destination)
        } else {
            revealedToolDestinations.insert(destination)
        }
    }

    func isToolRevealVisible(for destination: MainDestination) -> Bool {
        revealedToolDestinations.contains(destination)
    }
}
