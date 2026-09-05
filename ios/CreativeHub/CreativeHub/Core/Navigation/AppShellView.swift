import SwiftUI

struct AppShellView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var overviewViewModel = OverviewViewModel()
    @StateObject private var videoTaskViewModel = VideoTaskViewModel()
    @StateObject private var contentPlanViewModel = ContentPlanViewModel()
    @StateObject private var membersViewModel = MembersViewModel()
    @StateObject private var notificationViewModel = NotificationViewModel()
    @StateObject private var profileViewModel = ProfileViewModel()
    @StateObject private var notificationRefreshLoop = InAppNotificationRefreshLoop()

    var body: some View {
        ZStack(alignment: .bottom) {
            CHColors.appBackground
                .ignoresSafeArea()

            mainLayer
                .offset(x: router.activeSecondary == nil ? 0 : -24)
                .opacity(router.activeSecondary == nil ? 1 : 0.24)
                .animation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.32), value: router.activeSecondary)

            if router.isBottomNavigationVisible {
                CHBottomNavigation(selected: Binding(
                    get: { router.selectedMain },
                    set: { router.selectMain($0) }
                ))
                .transition(.chBottomNavigation)
                .zIndex(3)
            }

            if let secondary = router.activeSecondary {
                SecondaryScaffold(
                    destination: secondary,
                    notificationViewModel: notificationViewModel,
                    profileViewModel: profileViewModel,
                    profileID: appState.currentProfileID,
                    currentUser: appState.currentUser,
                    canEditProfile: appState.can(.profileEditSelf),
                    notificationPolicy: notificationPolicy,
                    openNotificationDestination: openNotificationDestination,
                    refreshProfileShell: { profile in
                        appState.updateCurrentUserSummary(
                            displayName: profile.displayIdentity,
                            email: profile.email,
                            avatarURL: profile.avatarURL
                        )
                    },
                    signOutFromProfile: {
                        #if DEBUG
                        if let rawDelay = ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE11_FIX03_SIGNOUT_DELAY_MS"],
                           let milliseconds = UInt64(rawDelay) {
                            try? await Task.sleep(nanoseconds: milliseconds * 1_000_000)
                        }
                        #endif
                        let signedOut = await appState.signOutAndReturnToLogin()
                        if signedOut {
                            notificationRefreshLoop.stop()
                            router.resetForLogout()
                        }
                        return signedOut
                    },
                    showToast: appState.showToast
                )
                    .transition(.chSecondaryRoute)
                    .zIndex(8)
            }

            if let module = router.activeModule {
                CHModuleScaffold(title: moduleTitle(for: module), onBack: {
                    withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.26)) {
                        if isCalendarModule(module) {
                            calendarViewModel.clearModule()
                        }
                        if isVideoTaskModule(module) {
                            videoTaskViewModel.clearModule()
                        }
                        if isContentPlanModule(module) {
                            contentPlanViewModel.clearModule()
                        }
                        if isMemberModule(module) {
                            membersViewModel.clearModule()
                        }
                        router.pop()
                    }
                }, contentScrolls: !isMemberModule(module)) {
                    if isCalendarModule(module) {
                        CalendarModuleView(
                            viewModel: calendarViewModel,
                            permissions: calendarPermissions,
                            closeWithToast: { toast in
                                withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.26)) {
                                    calendarViewModel.clearModule()
                                    router.pop()
                                }
                                if let toast {
                                    appState.showToast(toast)
                                }
                            }
                        )
                    } else if isVideoTaskModule(module) {
                        VideoTaskModuleView(
                            viewModel: videoTaskViewModel,
                            permissions: videoTaskPermissions,
                            closeWithToast: { toast in
                                withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.26)) {
                                    videoTaskViewModel.clearModule()
                                    router.pop()
                                }
                                if let toast {
                                    appState.showToast(toast)
                                }
                            }
                        )
                    } else if isContentPlanModule(module) {
                        ContentPlanModuleView(
                            viewModel: contentPlanViewModel,
                            permissions: contentPlanPermissions,
                            closeWithToast: { toast in
                                withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.26)) {
                                    contentPlanViewModel.clearModule()
                                    router.pop()
                                }
                                if let toast {
                                    appState.showToast(toast)
                                }
                            }
                        )
                    } else if isMemberModule(module) {
                        MemberModuleView(
                            viewModel: membersViewModel,
                            permissions: memberPermissions,
                            closeWithToast: { toast in
                                withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.26)) {
                                    membersViewModel.clearModule()
                                    router.pop()
                                }
                                if let toast {
                                    appState.showToast(toast)
                                }
                            }
                        )
                    } else {
                        Phase3ModuleBody(module: module) {
                            appState.showToast(CHToastItem(kind: .neutral, message: "Shell Phase 3"))
                        }
                    }
                }
                .transition(.chModuleRoute)
                .zIndex(10)
            }
        }
        .animation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.24), value: router.isBottomNavigationVisible)
        .task(id: appState.currentProfileID) {
            await videoTaskViewModel.configurePreferenceProfile(appState.currentProfileID)
            await calendarViewModel.configurePreferenceProfile(appState.currentProfileID)
            await contentPlanViewModel.configurePreferenceProfile(appState.currentProfileID)
            await notificationViewModel.load(silent: true)
            reconcileInAppNotificationRefreshLoop()
        }
        .onChange(of: scenePhase) { (_: ScenePhase, newPhase: ScenePhase) in
            let isSceneActive: Bool = newPhase == ScenePhase.active
            reconcileInAppNotificationRefreshLoop(isSceneActive: isSceneActive)
            guard isSceneActive else { return }
            Task {
                await refreshInAppNotificationsSilently()
            }
        }
        .onChange(of: router.activeSecondary) { oldValue, newValue in
            guard oldValue != nil, newValue == nil else { return }
            Task {
                await refreshInAppNotificationsSilently()
            }
        }
        .onChange(of: notificationRefreshLoop.tick) { _, _ in
            Task {
                await refreshInAppNotificationsSilently()
            }
        }
    }

    private var mainLayer: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, CHSpacing.screen)
                .padding(.top, 4)
                .zIndex(2)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if router.selectedMain.canRevealTools {
                        if router.selectedMain != .calendar && router.selectedMain != .video && router.selectedMain != .content && router.selectedMain != .members {
                            ToolRevealPanel(
                                destination: router.selectedMain,
                                isOpen: router.isToolRevealVisible(for: router.selectedMain),
                                isQAHarnessEnabled: Phase3QAHarness.isEnabled,
                                openModule: {
                                    withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.34)) {
                                        router.pushModule(.phase3Harness(origin: router.selectedMain))
                                    }
                                },
                                showToast: {
                                    appState.showToast(CHToastItem(kind: .neutral, message: "Shell Phase 3"))
                                }
                            )
                        }
                    }

                    currentMainScreen
                }
                .padding(.horizontal, CHSpacing.screen)
                .padding(.top, 16)
                .padding(.bottom, 110)
            }
            .refreshable {
                await refreshCurrentMainScreen()
            }
        }
    }

    private var topBar: some View {
        let destination = router.selectedMain
        return CHGlassTopBar(
            mode: destination == .overview
                ? .overview(displayName: appState.currentUser.displayName)
                : .main(title: destination.topBarTitle),
            hasUnreadNotifications: notificationViewModel.hasUnread,
            onLeading: {
                withAnimation(.timingCurve(0.2, 0.75, 0.25, 1, duration: 0.26)) {
                    router.toggleToolReveal(for: destination)
                }
            },
            onNotifications: {
                withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.32)) {
                    router.pushSecondary(.notifications)
                }
            },
            onAvatar: {
                withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.32)) {
                    router.pushSecondary(.profile)
                }
            }
        )
    }

    @ViewBuilder
    private var currentMainScreen: some View {
        switch router.selectedMain {
        case .overview:
            OverviewView(viewModel: overviewViewModel)
        case .video:
            VideoTaskView(
                viewModel: videoTaskViewModel,
                isToolsOpen: router.isToolRevealVisible(for: .video),
                permissions: videoTaskPermissions,
                openModule: { module in
                    withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.34)) {
                        router.pushModule(module)
                    }
                },
                isPhase3QAHarnessEnabled: Phase3QAHarness.isEnabled,
                showPhase3QAToast: {
                    appState.showToast(CHToastItem(kind: .neutral, message: "Shell Phase 3"))
                }
            )
        case .calendar:
            CalendarView(
                viewModel: calendarViewModel,
                isFiltersOpen: router.isToolRevealVisible(for: .calendar),
                permissions: calendarPermissions,
                openModule: { module in
                    withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.34)) {
                        router.pushModule(module)
                    }
                }
            )
        case .content:
            ContentPlanView(
                viewModel: contentPlanViewModel,
                isToolsOpen: router.isToolRevealVisible(for: .content),
                permissions: contentPlanPermissions,
                openModule: { module in
                    withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.34)) {
                        router.pushModule(module)
                    }
                }
            )
        case .members:
            MembersPlaceholderView(
                viewModel: membersViewModel,
                isToolsOpen: router.isToolRevealVisible(for: .members),
                permissions: memberPermissions,
                openModule: { module in
                    withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.34)) {
                        router.pushModule(module)
                    }
                }
            )
        }
    }

    private func refreshCurrentMainScreen() async {
        let message: String?
        switch router.selectedMain {
        case .overview:
            message = await overviewViewModel.refresh()
        case .video:
            message = await videoTaskViewModel.refresh()
        case .calendar:
            message = await calendarViewModel.refresh()
        case .content:
            message = await contentPlanViewModel.refresh()
        case .members:
            message = await membersViewModel.refresh()
        }

        if let message {
            appState.showToast(CHToastItem(kind: .error, message: message))
        }
    }

    private var calendarPermissions: CalendarPermissions {
        CalendarPermissions(
            canCreate: appState.can(.shootsCreate),
            canUpdate: appState.can(.shootsUpdate),
            canDelete: appState.can(.shootsDelete)
        )
    }

    private var videoTaskPermissions: VideoTaskPermissions {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE6_VIDEO_TASKS_PERMISSION"] {
        case "readonly":
            return VideoTaskPermissions(canCreate: false, canUpdate: false, canDelete: false, isAdmin: false, currentProfileID: appState.currentProfileID)
        case "create-only":
            return VideoTaskPermissions(canCreate: true, canUpdate: false, canDelete: false, isAdmin: false, currentProfileID: appState.currentProfileID)
        case "update":
            return VideoTaskPermissions(canCreate: false, canUpdate: true, canDelete: false, isAdmin: false, currentProfileID: appState.currentProfileID)
        case "update-delete":
            return VideoTaskPermissions(canCreate: false, canUpdate: true, canDelete: true, isAdmin: false, currentProfileID: appState.currentProfileID)
        case "delete":
            return VideoTaskPermissions(canCreate: false, canUpdate: false, canDelete: true, isAdmin: false, currentProfileID: appState.currentProfileID)
        default:
            break
        }
        #endif
        return VideoTaskPermissions(
            canCreate: appState.can(.videoTasksCreate),
            canUpdate: appState.can(.videoTasksUpdate),
            canDelete: appState.can(.videoTasksDelete),
            isAdmin: appState.currentRole == .admin,
            currentProfileID: appState.currentProfileID
        )
    }

    private var contentPlanPermissions: ContentPlanPermissions {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE7_CONTENT_PLAN_PERMISSION"] {
        case "readonly":
            return ContentPlanPermissions(canCreate: false, canUpdate: false, canAssign: false, canDelete: false, isAdmin: false, currentProfileID: appState.currentProfileID)
        case "create-only":
            return ContentPlanPermissions(canCreate: true, canUpdate: false, canAssign: false, canDelete: false, isAdmin: false, currentProfileID: appState.currentProfileID)
        case "update":
            return ContentPlanPermissions(canCreate: false, canUpdate: true, canAssign: false, canDelete: false, isAdmin: false, currentProfileID: appState.currentProfileID)
        case "assign":
            return ContentPlanPermissions(canCreate: false, canUpdate: false, canAssign: true, canDelete: false, isAdmin: false, currentProfileID: appState.currentProfileID)
        case "update-assign":
            return ContentPlanPermissions(canCreate: false, canUpdate: true, canAssign: true, canDelete: false, isAdmin: false, currentProfileID: appState.currentProfileID)
        case "update-assign-delete":
            return ContentPlanPermissions(canCreate: false, canUpdate: true, canAssign: true, canDelete: true, isAdmin: false, currentProfileID: appState.currentProfileID)
        default:
            break
        }
        #endif
        return ContentPlanPermissions(
            canCreate: appState.can(.contentPlanCreate),
            canUpdate: appState.can(.contentPlanUpdate),
            canAssign: appState.can(.contentPlanAssign),
            canDelete: appState.can(.contentPlanDelete),
            isAdmin: appState.currentRole == .admin,
            currentProfileID: appState.currentProfileID
        )
    }

    private var memberPermissions: MemberPermissions {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE8_MEMBERS_PERMISSION"] {
        case "readonly":
            return MemberPermissions(canView: true, canCreate: false, canUpdate: false, isAdmin: false, currentProfileID: appState.currentProfileID)
        case "update":
            return MemberPermissions(canView: true, canCreate: false, canUpdate: true, isAdmin: true, currentProfileID: appState.currentProfileID)
        default:
            break
        }
        #endif
        return MemberPermissions(
            canView: appState.can(.userManagementView),
            canCreate: appState.can(.userManagementCreate),
            canUpdate: appState.can(.userManagementUpdate),
            isAdmin: appState.currentRole == .admin,
            currentProfileID: appState.currentProfileID
        )
    }

    private var notificationPolicy: NotificationNavigationPolicy {
        NotificationNavigationPolicy(
            canOpenCalendar: appState.can(.shootsView),
            canOpenVideo: appState.can(.videoTasksView),
            canOpenContent: appState.can(.contentPlanView),
            canOpenMembers: appState.can(.userManagementView)
        )
    }

    private func isCalendarModule(_ module: ModuleDestination) -> Bool {
        switch module {
        case .shootCreate, .shootEdit:
            true
        default:
            false
        }
    }

    private func isVideoTaskModule(_ module: ModuleDestination) -> Bool {
        switch module {
        case .taskCreate, .taskEdit:
            true
        default:
            false
        }
    }

    private func isContentPlanModule(_ module: ModuleDestination) -> Bool {
        switch module {
        case .contentCreate, .contentEdit:
            true
        default:
            false
        }
    }

    private func isMemberModule(_ module: ModuleDestination) -> Bool {
        switch module {
        case .memberCreate, .memberEdit:
            true
        default:
            false
        }
    }

    private func moduleTitle(for module: ModuleDestination) -> String {
        if isCalendarModule(module), let mode = calendarViewModel.moduleMode {
            return mode.title
        }
        if isVideoTaskModule(module), let mode = videoTaskViewModel.moduleMode {
            return mode.title
        }
        if isContentPlanModule(module), let mode = contentPlanViewModel.moduleMode {
            return mode.title
        }
        if isMemberModule(module), let mode = membersViewModel.moduleMode {
            return mode.title
        }
        return module.title
    }

    private func openNotificationDestination(_ destination: NotificationDestination) async -> Bool {
        switch destination {
        case .overview:
            withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.32)) {
                router.selectMain(.overview)
            }
            return true
        case .members:
            await membersViewModel.load()
            withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.32)) {
                router.selectMain(.members)
            }
            return true
        case .calendarShoot(let id):
            if case .idle = calendarViewModel.loadState {
                await calendarViewModel.load()
            }
            guard let shoot = calendarViewModel.shoots.first(where: { $0.id == id }) else {
                return false
            }
            calendarViewModel.open(shoot: shoot, canUpdate: calendarPermissions.canUpdate)
            withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.32)) {
                router.selectMain(.calendar)
                router.pushModule(.shootEdit(id: id.uuidString))
            }
            return true
        case .videoTask(let id):
            await videoTaskViewModel.loadIfNeeded()
            guard let task = videoTaskViewModel.tasks.first(where: { $0.id == id }) else {
                return false
            }
            videoTaskViewModel.open(task: task, permissions: videoTaskPermissions)
            withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.32)) {
                router.selectMain(.video)
                router.pushModule(.taskEdit(id: id.uuidString))
            }
            return true
        case .contentPlan(let id):
            await contentPlanViewModel.loadIfNeeded()
            guard let item = contentPlanViewModel.items.first(where: { $0.id == id }) else {
                return false
            }
            contentPlanViewModel.open(item: item, permissions: contentPlanPermissions)
            withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.32)) {
                router.selectMain(.content)
                router.pushModule(.contentEdit(id: id.uuidString))
            }
            return true
        case .passive, .unavailable:
            return false
        }
    }

    private func refreshInAppNotificationsSilently() async {
        guard appState.currentProfileID != nil else { return }
        if router.activeSecondary == .notifications {
            _ = await notificationViewModel.refresh()
        } else if case .idle = notificationViewModel.loadState {
            await notificationViewModel.load(silent: true)
        } else {
            await notificationViewModel.refreshUnreadIndicator()
        }
    }

    private func reconcileInAppNotificationRefreshLoop(isSceneActive: Bool? = nil) {
        let sceneIsActive: Bool = isSceneActive ?? (scenePhase == ScenePhase.active)
        notificationRefreshLoop.reconcile(
            isAuthenticated: appState.currentProfileID != nil,
            isSceneActive: sceneIsActive
        )
    }
}

private struct SecondaryScaffold: View {
    @EnvironmentObject private var router: AppRouter
    var destination: SecondaryDestination
    @ObservedObject var notificationViewModel: NotificationViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    var profileID: UUID?
    var currentUser: CurrentUserSummary
    var canEditProfile: Bool
    var notificationPolicy: NotificationNavigationPolicy
    var openNotificationDestination: (NotificationDestination) async -> Bool
    var refreshProfileShell: (UserProfile) async -> Void
    var signOutFromProfile: () async -> Bool
    var showToast: (CHToastItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(destination.id)
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("secondary.\(destination.id)")

            CHGlassTopBar(mode: .secondary(title: destination.title), onLeading: {
                withAnimation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.32)) {
                    router.pop()
                }
            })
            .padding(.horizontal, CHSpacing.screen)
            .padding(.top, 4)

            switch destination {
            case .notifications:
                NotificationsView(
                    viewModel: notificationViewModel,
                    navigationPolicy: notificationPolicy,
                    onOpenDestination: openNotificationDestination,
                    onShowToast: showToast
                )
            case .profile:
                ProfileView(
                    viewModel: profileViewModel,
                    profileID: profileID,
                    fallbackUser: currentUser,
                    canEdit: canEditProfile,
                    refreshShell: refreshProfileShell,
                    signOut: signOutFromProfile,
                    onShowToast: showToast
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CHColors.appBackground.ignoresSafeArea())
    }
}

private struct ToolRevealPanel: View {
    var destination: MainDestination
    var isOpen: Bool
    var isQAHarnessEnabled: Bool
    var openModule: () -> Void
    var showToast: () -> Void

    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            Text(isOpen ? "open" : "closed")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("tool-reveal.state.\(destination.rawValue).\(isOpen ? "open" : "closed")")

            VStack(spacing: 7) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CHColors.purple)
                    TextField(searchPlaceholder, text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(CHTypography.caption)
                        .accessibilityIdentifier("tool-reveal.search.\(destination.rawValue)")
                }
                .padding(.horizontal, 11)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CHColors.line, lineWidth: 1))
                )

                HStack(spacing: 7) {
                    toolChip("Trạng thái")
                    toolChip(destination == .members ? "Vai trò" : "Thời gian")
                    toolChip(destination == .content ? "Loại" : "Nhóm")
                    Spacer(minLength: 0)
                    if isQAHarnessEnabled {
                        iconButton(systemName: "rectangle.portrait.and.arrow.right", identifier: "module.open-test", action: openModule)
                        iconButton(systemName: "bubble.left.and.text.bubble.right", identifier: "phase3.show-toast", action: showToast)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.white.opacity(0.46))
                    .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.white.opacity(0.52), lineWidth: 1))
                    .shadow(color: CHShadow.softColor, radius: 10, y: 7)
            )
            .frame(maxHeight: isOpen ? nil : 0, alignment: .top)
            .opacity(isOpen ? 1 : 0)
            .offset(y: isOpen ? 0 : -7)
            .clipped()
            .allowsHitTesting(isOpen)
            .accessibilityHidden(!isOpen)
        }
        .padding(.bottom, isOpen ? 8 : 0)
        .animation(.timingCurve(0.2, 0.75, 0.25, 1, duration: 0.26), value: isOpen)
    }

    private var searchPlaceholder: String {
        switch destination {
        case .overview:
            ""
        case .video:
            "Tìm video..."
        case .calendar:
            "Tìm lịch quay..."
        case .content:
            "Tìm nội dung..."
        case .members:
            "Tìm thành viên..."
        }
    }

    private func toolChip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(CHColors.muted)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.74))
                    .overlay(Capsule().stroke(CHColors.line, lineWidth: 1))
            )
    }

    private func iconButton(systemName: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(CHColors.purple)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.80))
                        .overlay(Circle().stroke(CHColors.line, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

private struct CHModuleScaffold<Content: View>: View {
    var title: String
    var onBack: () -> Void
    var contentScrolls: Bool
    private let content: Content

    init(title: String, onBack: @escaping () -> Void, contentScrolls: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.onBack = onBack
        self.contentScrolls = contentScrolls
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("module.scaffold")

            CHGlassTopBar(mode: .module(title: title), onLeading: onBack)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            if contentScrolls {
                ScrollView(.vertical, showsIndicators: false) {
                    content
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 18)
                }
            } else {
                content
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CHColors.appBackground.ignoresSafeArea())
    }
}

private struct Phase3ModuleBody: View {
    var module: ModuleDestination
    var showToast: () -> Void
    @State private var text = ""

    var body: some View {
        Group {
            if Phase3QAHarness.isEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text(originCopy)
                        .font(CHTypography.caption)
                        .foregroundStyle(CHColors.muted)

                    TextField("Nhập thử", text: $text)
                        .font(CHTypography.body)
                        .padding(.horizontal, 13)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.90))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(CHColors.line, lineWidth: 1))
                        )
                        .accessibilityIdentifier("module.input")

                    Button(action: showToast) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(CHColors.purple))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("phase3.show-toast-hidden")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.84))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.78), lineWidth: 1))
                        .shadow(color: CHShadow.softColor, radius: 18, y: 12)
                )
            } else {
                CHStateView(
                    kind: .empty,
                    title: module.title,
                    message: "Nội dung sẽ hiển thị tại đây."
                )
                .frame(minHeight: 560)
                .accessibilityIdentifier("module.placeholder")
            }
        }
    }

    private var originCopy: String {
        if case .phase3Harness(let origin) = module {
            return "Nguồn: \(origin.topBarTitle)"
        }
        return "Module toàn màn hình"
    }
}

private enum Phase3QAHarness {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["CREATIVEHUB_PHASE3_QA_HARNESS"] == "1"
        #else
        false
        #endif
    }
}

private struct OffsetOpacityModifier: ViewModifier {
    var x: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(x: x)
            .opacity(opacity)
    }
}

private extension AnyTransition {
    static var chSecondaryRoute: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: OffsetOpacityModifier(x: 34, opacity: 0.56),
                identity: OffsetOpacityModifier(x: 0, opacity: 1)
            ),
            removal: .modifier(
                active: OffsetOpacityModifier(x: 24, opacity: 0.24),
                identity: OffsetOpacityModifier(x: 0, opacity: 1)
            )
        )
    }

    static var chModuleRoute: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: OffsetOpacityModifier(x: 42, opacity: 0.70),
                identity: OffsetOpacityModifier(x: 0, opacity: 1)
            ),
            removal: .modifier(
                active: OffsetOpacityModifier(x: 34, opacity: 0.42),
                identity: OffsetOpacityModifier(x: 0, opacity: 1)
            )
        )
    }

    static var chBottomNavigation: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: BottomNavigationModifier(y: 12, opacity: 0),
                identity: BottomNavigationModifier(y: 0, opacity: 1)
            ),
            removal: .modifier(
                active: BottomNavigationModifier(y: 12, opacity: 0),
                identity: BottomNavigationModifier(y: 0, opacity: 1)
            )
        )
    }
}

private struct BottomNavigationModifier: ViewModifier {
    var y: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(y: y)
            .scaleEffect(y == 0 ? 1 : 0.97)
            .opacity(opacity)
    }
}

#Preview("App Shell") {
    AppShellView()
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
