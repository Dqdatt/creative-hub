import XCTest
import UIKit
@testable import CreativeHubOps

final class CreativeHubOpsTests: XCTestCase {
    func testMainTabTitlesStayVietnamese() {
        XCTAssertEqual(MainTab.dashboard.title, "Tổng quan")
        XCTAssertEqual(MainTab.tasks.title, "Video")
        XCTAssertEqual(MainTab.calendar.title, "Lịch quay")
        XCTAssertEqual(MainTab.profile.title, "Cá nhân")
    }

    func testDetailRoutesCarryStableIds() {
        XCTAssertEqual(AppRoute.taskDetail("task-1"), AppRoute.taskDetail("task-1"))
        XCTAssertNotEqual(AppRoute.taskDetail("task-1"), AppRoute.taskDetail("task-2"))
        XCTAssertEqual(AppRoute.shootDetail("shoot-1"), AppRoute.shootDetail("shoot-1"))
        XCTAssertEqual(AppRoute.contentPlanDetail("content-1"), AppRoute.contentPlanDetail("content-1"))
        XCTAssertEqual(AppRoute.userDetail("dat"), AppRoute.userDetail("dat"))
    }

    func testEditSheetsAreSeparateFromDetailRoutes() {
        XCTAssertEqual(AppSheet.taskEdit.id, "taskEdit")
        XCTAssertEqual(AppSheet.shootEdit.id, "shootEdit")
        XCTAssertEqual(AppSheet.contentPlanEdit.id, "contentPlanEdit")
    }

    func testPlaceholderSupabaseConfigIsRejected() {
        XCTAssertThrowsError(
            try AppConfig(
                urlString: "https:/$()/your-project-ref.supabase.co",
                anonKey: "your-supabase-anon-or-publishable-key"
            )
        )
    }

    func testValidSupabaseConfigIsAccepted() throws {
        let config = try AppConfig(
            urlString: "https://example.supabase.co",
            anonKey: "publishable-key"
        )

        XCTAssertEqual(config.supabaseURL.absoluteString, "https://example.supabase.co")
        XCTAssertEqual(config.supabaseAnonKey, "publishable-key")
    }

    func testContentPlanCategoriesMatchProductionSet() {
        XCTAssertEqual(
            ContentPlanCategory.allCases.map(\.rawValue),
            ["Video dài", "Short/Reels", "Livestream", "Ảnh", "Motion", "Ads"]
        )
    }

    func testDashboardProgressUsesCompletedTasks() {
        let tasks = [
            VideoTask.fixture(status: .done),
            VideoTask.fixture(status: .doing),
            VideoTask.fixture(status: .waiting),
        ]
        let summary = DashboardSummary(tasks: tasks, shoots: [], editors: [])

        XCTAssertEqual(summary.totalTasks, 3)
        XCTAssertEqual(summary.completedTasks, 1)
        XCTAssertEqual(summary.inProgressTasks, 1)
        XCTAssertEqual(summary.pendingTasks, 1)
        XCTAssertEqual(summary.progress, 1.0 / 3.0, accuracy: 0.001)
    }

    func testEditorWorkloadCountsTasksAndShoots() {
        let editor = EditorProfile(
            id: "dat",
            profileId: "profile-dat",
            name: "Đạt",
            shortName: "Đạt",
            initial: "Đ",
            colorHex: "#0ea5e9",
            avatarURL: "",
            role: "editor"
        )
        let tasks = [
            VideoTask.fixture(status: .doing, editorId: "dat", category: "Video dài", resizeRequirements: "9x16 & 1x1"),
            VideoTask.fixture(status: .waiting, editorId: "profile-dat", category: "Motion", resizeRequirements: ""),
        ]
        let shoots = [
            ShootSchedule.fixture(type: "lichquay", editorIds: ["dat"], editorProfileIds: ["profile-dat"]),
            ShootSchedule.fixture(type: "livestream", editorIds: ["dat"], editorProfileIds: ["profile-dat"]),
        ]
        let summary = DashboardSummary(tasks: tasks, shoots: shoots, editors: [editor])
        let workload = summary.editorWorkloads[0]

        XCTAssertEqual(workload.longVideoCount, 1)
        XCTAssertEqual(workload.motionCount, 1)
        XCTAssertEqual(workload.resizeCount, 2)
        XCTAssertEqual(workload.shootCount, 1)
    }

    func testTaskDateNormalizationMatchesWebInputs() throws {
        XCTAssertEqual(
            try AppDateFormatter.normalizedDatabaseDate("7/8", label: "Ngày Air"),
            "2026-08-07"
        )
        XCTAssertEqual(
            try AppDateFormatter.normalizedDatabaseDate("2026-08-07", label: "Ngày Air"),
            "2026-08-07"
        )
        XCTAssertNil(try AppDateFormatter.normalizedDatabaseDate("", label: "Ngày Air"))
        XCTAssertThrowsError(try AppDateFormatter.normalizedDatabaseDate("31/2", label: "Ngày Air"))
    }

    func testMonthRangeHandlesLeapYearAndYearBoundary() throws {
        let calendar = Calendar(identifier: .gregorian)
        let leapDate = try XCTUnwrap(Self.date("2024-02-29", calendar: calendar))
        let yearEndDate = try XCTUnwrap(Self.date("2026-12-31", calendar: calendar))

        let leapRange = AppDateFormatter.monthRange(containing: leapDate, calendar: calendar)
        XCTAssertEqual(leapRange.value, "2024-02")
        XCTAssertEqual(leapRange.startDate, "2024-02-01")
        XCTAssertEqual(leapRange.endDate, "2024-02-29")

        let yearEndRange = AppDateFormatter.monthRange(containing: yearEndDate, calendar: calendar)
        XCTAssertEqual(yearEndRange.value, "2026-12")
        XCTAssertEqual(yearEndRange.startDate, "2026-12-01")
        XCTAssertEqual(yearEndRange.endDate, "2026-12-31")
    }

    func testOptionalHTTPURLValidation() throws {
        XCTAssertNil(try AppDateFormatter.normalizedOptionalHTTPURL(""))
        XCTAssertNil(try AppDateFormatter.normalizedOptionalHTTPURL("#"))
        XCTAssertEqual(
            try AppDateFormatter.normalizedOptionalHTTPURL("https://example.com/video"),
            "https://example.com/video"
        )
        XCTAssertThrowsError(try AppDateFormatter.normalizedOptionalHTTPURL("ftp://example.com/video"))
    }

    func testTaskEditFormMapsEditorProfileIdToEditorCode() {
        let editor = EditorProfile(
            id: "dat",
            profileId: "A4F93D57-01F9-4CC2-8F74-585BF93F6987",
            name: "Đạt",
            shortName: "Đạt",
            initial: "Đ",
            colorHex: "#0ea5e9",
            avatarURL: "",
            role: "editor"
        )
        let task = VideoTask.fixture(
            status: .doing,
            editorId: "A4F93D57-01F9-4CC2-8F74-585BF93F6987",
            category: "Motion",
            resizeRequirements: "9x16"
        )

        let form = VideoTaskFormData(task: task, editors: [editor])

        XCTAssertEqual(form.editorCode, "dat")
        XCTAssertEqual(form.title, "Task")
        XCTAssertEqual(form.status, .doing)
        XCTAssertEqual(form.category, "Motion")
    }

    func testTaskEditFormPreservesUnknownUUIDEditorValue() {
        let uuid = "A4F93D57-01F9-4CC2-8F74-585BF93F6987"
        let task = VideoTask.fixture(status: .waiting, editorId: uuid)

        let form = VideoTaskFormData(task: task, editors: [])

        XCTAssertEqual(form.editorCode, uuid)
        XCTAssertTrue(VideoTaskFormData.looksLikeUUID(form.editorCode))
    }

    func testShootFormMapsExistingSchedule() {
        let shoot = ShootSchedule.fixture(
            type: "livestream",
            editorIds: ["dat", "hai"],
            editorProfileIds: ["profile-dat", "profile-hai"]
        )

        let form = ShootFormData(shoot: shoot)

        XCTAssertEqual(form.date, "2026-08-07")
        XCTAssertEqual(form.type, .livestream)
        XCTAssertEqual(form.editorIds, Set(["dat", "hai"]))
    }

    func testShootTypeLabelsStayVietnamese() {
        XCTAssertEqual(ShootType.lichquay.label, "Lịch quay")
        XCTAssertEqual(ShootType.livestream.label, "Livestream")
        XCTAssertEqual(ShootType.onset.label, "On set")
        XCTAssertEqual(ShootType.other.label, "Khác")
    }

    func testContentPlanFormMapsExistingItem() {
        let item = ContentPlanItem(
            id: "content-1",
            airDate: "2026-08-07",
            title: "Video launch",
            note: "Ghi chú",
            category: .ads,
            editorId: "dat",
            link: "https://example.com/final",
            hasLinkedTask: true
        )

        let form = ContentPlanFormData(item: item)

        XCTAssertEqual(form.airDate, "2026-08-07")
        XCTAssertEqual(form.title, "Video launch")
        XCTAssertEqual(form.category, .ads)
        XCTAssertEqual(form.editorCode, "dat")
        XCTAssertEqual(form.link, "https://example.com/final")
    }

    func testAdminRoleReceivesAllPermissions() {
        let permissions = PermissionService.effectivePermissions(role: .admin, override: nil)

        XCTAssertEqual(permissions, Set(Permission.allCases))
    }

    func testViewOnlyOverrideRemovesMutationPermissions() {
        let override = UserPermissionOverride(accessMode: .viewOnly, flags: [:])
        let permissions = PermissionService.effectivePermissions(role: .admin, override: override)

        XCTAssertTrue(permissions.contains(.dashboardView))
        XCTAssertFalse(permissions.contains(.videoTasksCreate))
        XCTAssertFalse(permissions.contains(.shootsDelete))
        XCTAssertFalse(permissions.contains(.contentPlanAssign))
        XCTAssertFalse(permissions.contains(.userManagementView))
        XCTAssertFalse(permissions.contains(.profileEditSelf))
    }

    func testCustomOverrideEnablesViewWhenEditIsEnabled() {
        let override = UserPermissionOverride(
            accessMode: .custom,
            flags: [
                .dashboardView: false,
                .tasksView: false,
                .tasksEdit: true,
                .calendarView: false,
                .calendarEdit: true,
                .contentPlanView: false,
                .contentPlanEditContent: true,
                .contentPlanAssignEditor: true,
                .profileEditSelf: nil,
            ]
        )
        let permissions = PermissionService.effectivePermissions(role: .editor, override: override)

        XCTAssertFalse(permissions.contains(.dashboardView))
        XCTAssertTrue(permissions.contains(.videoTasksView))
        XCTAssertTrue(permissions.contains(.videoTasksCreate))
        XCTAssertTrue(permissions.contains(.shootsView))
        XCTAssertTrue(permissions.contains(.shootsUpdate))
        XCTAssertTrue(permissions.contains(.contentPlanView))
        XCTAssertTrue(permissions.contains(.contentPlanAssign))
        XCTAssertTrue(permissions.contains(.profileEditSelf))
    }

    func testLinkedTaskStateMapsManualAndLinkedStatuses() {
        XCTAssertEqual(LinkedTaskState(task: VideoTask.fixture(status: .waiting, contentPlanId: nil)), .manual)
        XCTAssertEqual(LinkedTaskState(task: VideoTask.fixture(status: .waiting, contentPlanId: "content-1")), .waiting)
        XCTAssertEqual(LinkedTaskState(task: VideoTask.fixture(status: .doing, contentPlanId: "content-1")), .doing)
        XCTAssertEqual(LinkedTaskState(task: VideoTask.fixture(status: .done, contentPlanId: "content-1")), .done)
    }

    func testLinkedTaskValidTransitionsUseAssignedEditorAndUpdatePermission() {
        let editor = EditorProfile.fixture(id: "dat", profileId: UUID().uuidString)
        let profile = CurrentUserProfile.fixture(
            id: UUID(uuidString: editor.profileId)!,
            role: .editor,
            permissions: [.videoTasksUpdate]
        )

        let waitingTask = VideoTask.fixture(status: .waiting, editorId: "dat", contentPlanId: "content-1")
        let doingTask = VideoTask.fixture(status: .doing, editorId: editor.profileId, contentPlanId: "content-1")

        XCTAssertTrue(LinkedTaskState(task: waitingTask).canAccept(task: waitingTask, currentProfile: profile, editors: [editor]))
        XCTAssertFalse(LinkedTaskState(task: waitingTask).canComplete(task: waitingTask, currentProfile: profile, editors: [editor]))
        XCTAssertTrue(LinkedTaskState(task: doingTask).canUpdateExecution(task: doingTask, currentProfile: profile, editors: [editor]))
        XCTAssertTrue(LinkedTaskState(task: doingTask).canComplete(task: doingTask, currentProfile: profile, editors: [editor]))
    }

    func testLinkedTaskInvalidTransitionsRejectWrongStateWrongEditorAndMissingPermission() {
        let assignedProfileId = UUID()
        let otherProfileId = UUID()
        let editor = EditorProfile.fixture(id: "dat", profileId: assignedProfileId.uuidString)
        let otherProfile = CurrentUserProfile.fixture(
            id: otherProfileId,
            role: .editor,
            permissions: [.videoTasksUpdate]
        )
        let noUpdateProfile = CurrentUserProfile.fixture(
            id: assignedProfileId,
            role: .editor,
            permissions: [.videoTasksView]
        )
        let doneTask = VideoTask.fixture(status: .done, editorId: "dat", contentPlanId: "content-1")
        let waitingTask = VideoTask.fixture(status: .waiting, editorId: "dat", contentPlanId: "content-1")

        XCTAssertFalse(LinkedTaskState(task: doneTask).canAccept(task: doneTask, currentProfile: otherProfile, editors: [editor]))
        XCTAssertFalse(LinkedTaskState(task: waitingTask).canAccept(task: waitingTask, currentProfile: otherProfile, editors: [editor]))
        XCTAssertFalse(LinkedTaskState(task: waitingTask).canAccept(task: waitingTask, currentProfile: noUpdateProfile, editors: [editor]))
    }

    func testLinkedTaskValidationRequiresCompletionLink() throws {
        XCTAssertThrowsError(try AppDateFormatter.normalizedRequiredHTTPURL(""))
        XCTAssertThrowsError(try AppDateFormatter.normalizedRequiredHTTPURL("ftp://example.com/file"))
        XCTAssertEqual(try AppDateFormatter.normalizedRequiredHTTPURL("https://example.com/file"), "https://example.com/file")
    }

    func testAvatarStoragePathMatchesWebConvention() {
        let userId = UUID(uuidString: "A4F93D57-01F9-4CC2-8F74-585BF93F6987")!
        let path = AvatarImageProcessor.storagePath(
            userId: userId,
            fileName: "My Avatar Ảnh.PNG",
            timestampMilliseconds: 1_786_162_000_000
        )

        XCTAssertEqual(path, "A4F93D57-01F9-4CC2-8F74-585BF93F6987/1786162000000-my-avatar-nh.png")
    }

    func testAvatarProcessorRejectsInvalidDataAndOversizedSource() {
        XCTAssertThrowsError(try AvatarImageProcessor.processedJPEGData(from: Data("not-image".utf8)))
        XCTAssertThrowsError(try AvatarImageProcessor.processedJPEGData(from: Data(repeating: 0, count: AvatarImageProcessor.maxSourceBytes + 1)))
    }

    func testAvatarProcessorOutputsJPEG() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
        let image = renderer.image { context in
            UIColor.systemPurple.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        let pngData = try XCTUnwrap(image.pngData())
        let jpegData = try AvatarImageProcessor.processedJPEGData(from: pngData)

        XCTAssertFalse(jpegData.isEmpty)
        XCTAssertEqual(AvatarImageProcessor.outputContentType, "image/jpeg")
        XCTAssertNotNil(UIImage(data: jpegData))
    }

    @MainActor
    func testNotificationRealtimeInsertDedupesAndUpdatesUnreadState() {
        let viewModel = NotificationsViewModel()
        let unread = InternalNotification.fixture(id: "noti-1", readAt: nil)
        let read = InternalNotification.fixture(id: "noti-1", readAt: "2026-08-08T00:00:00Z")

        viewModel.applyRealtimeInsert(unread)
        viewModel.applyRealtimeInsert(unread)
        viewModel.applyRealtimeUpdate(read)

        XCTAssertEqual(viewModel.notifications.count, 1)
        XCTAssertEqual(viewModel.unreadCount, 0)
        XCTAssertEqual(viewModel.notifications.first?.readAt, "2026-08-08T00:00:00Z")
    }

    @MainActor
    func testNotificationRealtimeDeleteAndLogoutCleanup() {
        let viewModel = NotificationsViewModel()
        viewModel.applyRealtimeInsert(.fixture(id: "noti-1", readAt: nil))
        viewModel.applyRealtimeInsert(.fixture(id: "noti-2", readAt: nil))

        viewModel.applyRealtimeDelete(notificationId: "noti-1")

        XCTAssertEqual(viewModel.notifications.map(\.id), ["noti-2"])
        XCTAssertEqual(viewModel.unreadCount, 1)

        viewModel.clearForLogout()

        XCTAssertTrue(viewModel.notifications.isEmpty)
        XCTAssertEqual(viewModel.unreadCount, 0)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testNotificationsLoadSkipsCachedDataUnlessForced() async {
        let repository = TestNotificationsRepository(notifications: [.fixture(id: "noti-1", readAt: nil)])
        let viewModel = NotificationsViewModel(repository: repository)

        await viewModel.load()
        await viewModel.load()
        XCTAssertEqual(repository.fetchCount, 1)

        await viewModel.load(force: true)
        XCTAssertEqual(repository.fetchCount, 2)
    }

    func testAdminUserFormValidationRequiresEmailNameAndEditorCode() {
        var form = AdminUserFormData()

        XCTAssertThrowsError(try form.validateForCreate())

        form.email = "editor@example.com"
        form.password = "123456"
        XCTAssertThrowsError(try form.validateForCreate())

        form.fullName = "Editor Demo"
        XCTAssertThrowsError(try form.validateForCreate())

        form.editorCode = "demo"
        XCTAssertNoThrow(try form.validateForCreate())
    }

    func testAdminUserFormMapsManagedProfilePermissionOverride() {
        let profile = ManagedUserProfile.fixture(
            permissionOverride: UserPermissionOverride(
                accessMode: .custom,
                flags: [
                    .dashboardView: false,
                    .tasksView: true,
                    .tasksEdit: true,
                    .profileEditSelf: false,
                ]
            )
        )

        let form = AdminUserFormData(profile: profile)

        XCTAssertEqual(form.email, "admin@example.com")
        XCTAssertEqual(form.role, .admin)
        XCTAssertEqual(form.permissionMode, .custom)
        XCTAssertFalse(form.dashboardView)
        XCTAssertTrue(form.tasksView)
        XCTAssertTrue(form.tasksEdit)
        XCTAssertFalse(form.profileEditSelf)
    }

    @MainActor
    func testOperationsAccountSwitchClearsSessionScopedState() async {
        let repository = TestOperationsRepository(
            tasks: [.fixture(status: .doing)],
            shoots: [.fixture(type: "lichquay", editorIds: ["dat"], editorProfileIds: [UUID().uuidString])],
            contentPlan: [
                ContentPlanItem(
                    id: "content-1",
                    airDate: "2026-08-07",
                    title: "Plan",
                    note: "",
                    category: .longVideo,
                    editorId: "dat",
                    link: "",
                    hasLinkedTask: false
                )
            ],
            editors: [.fixture(id: "dat", profileId: UUID().uuidString)]
        )
        let viewModel = OperationsViewModel(repository: repository)
        await viewModel.loadCurrentMonth()
        viewModel.selectedTask = viewModel.tasks.first

        viewModel.clearForAccountSwitch()

        XCTAssertTrue(viewModel.tasks.isEmpty)
        XCTAssertTrue(viewModel.shoots.isEmpty)
        XCTAssertTrue(viewModel.contentPlan.isEmpty)
        XCTAssertTrue(viewModel.editors.isEmpty)
        XCTAssertNil(viewModel.selectedTask)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isMutating)
    }

    @MainActor
    func testOperationsRejectsSecondMutationWhileFirstIsRunning() async throws {
        let repository = TestOperationsRepository()
        repository.pauseCreateVideoTask = true
        let viewModel = OperationsViewModel(repository: repository)

        let firstMutation = Task {
            try await viewModel.createVideoTask(VideoTaskFormData(), userId: nil)
        }

        for _ in 0..<20 where !viewModel.isMutating {
            await Task.yield()
        }

        XCTAssertTrue(viewModel.isMutating)
        do {
            try await viewModel.createVideoTask(VideoTaskFormData(), userId: nil)
            XCTFail("Expected duplicate mutation to be rejected.")
        } catch {
            XCTAssertEqual(
                AppError.map(error).localizedDescription,
                "Thao tác đang xử lý. Vui lòng đợi trong giây lát."
            )
        }

        repository.resumeCreateVideoTask()
        try await firstMutation.value
        XCTAssertFalse(viewModel.isMutating)
    }

    @MainActor
    func testAdminUsersAccountSwitchClearsSessionScopedState() async {
        let repository = TestAdminUserRepository(users: [.fixture(permissionOverride: .roleDefault)])
        let viewModel = AdminUsersViewModel(repository: repository)
        await viewModel.load()
        viewModel.selectedUser = viewModel.users.first

        viewModel.clearForAccountSwitch()

        XCTAssertTrue(viewModel.users.isEmpty)
        XCTAssertNil(viewModel.selectedUser)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.successMessage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isSaving)
    }

    @MainActor
    func testAdminUsersLoadSkipsCachedDataUnlessForced() async {
        let repository = TestAdminUserRepository(users: [.fixture(permissionOverride: .roleDefault)])
        let viewModel = AdminUsersViewModel(repository: repository)

        await viewModel.load()
        await viewModel.load()
        XCTAssertEqual(repository.fetchCount, 1)

        await viewModel.load(force: true)
        XCTAssertEqual(repository.fetchCount, 2)
    }

    @MainActor
    func testOperationsIgnoresStaleMonthLoadResult() async throws {
        let repository = TestOperationsRepository()
        repository.tasksByStartDate = [
            "2026-08-01": [.fixture(status: .waiting, title: "Tháng 8")],
            "2026-09-01": [.fixture(status: .doing, title: "Tháng 9")],
        ]
        repository.pausedVideoTaskFetchStartDates = ["2026-08-01"]
        let viewModel = OperationsViewModel(repository: repository)
        let august = try XCTUnwrap(Self.date("2026-08-09"))
        let september = try XCTUnwrap(Self.date("2026-09-09"))

        let staleLoad = Task { @MainActor in
            await viewModel.loadMonth(containing: august)
        }

        for _ in 0..<50 where !repository.hasPendingVideoTaskFetch(startDate: "2026-08-01") {
            await Task.yield()
        }
        XCTAssertTrue(repository.hasPendingVideoTaskFetch(startDate: "2026-08-01"))

        await viewModel.loadMonth(containing: september)
        XCTAssertEqual(viewModel.monthRange.value, "2026-09")
        XCTAssertEqual(viewModel.tasks.map(\.title), ["Tháng 9"])

        repository.resumeVideoTaskFetch(startDate: "2026-08-01")
        await staleLoad.value

        XCTAssertEqual(viewModel.monthRange.value, "2026-09")
        XCTAssertEqual(viewModel.tasks.map(\.title), ["Tháng 9"])
        XCTAssertFalse(viewModel.isLoading)
    }

    private static func date(_ value: String, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

private extension VideoTask {
    static func fixture(
        status: TaskStatus,
        title: String = "Task",
        editorId: String? = nil,
        category: String = ContentPlanCategory.longVideo.rawValue,
        resizeRequirements: String = "",
        contentPlanId: String? = nil
    ) -> VideoTask {
        VideoTask(
            id: UUID().uuidString,
            sequence: nil,
            title: title,
            resizeRequirements: resizeRequirements,
            editorId: editorId,
            orderTeam: "BRAND",
            category: category,
            receiveDate: nil,
            returnDate: nil,
            airDate: "2026-08-07",
            status: status,
            priority: "",
            resultLink: "",
            notes: "",
            contentPlanId: contentPlanId
        )
    }
}

private extension EditorProfile {
    static func fixture(id: String, profileId: String) -> EditorProfile {
        EditorProfile(
            id: id,
            profileId: profileId,
            name: "Editor",
            shortName: "Editor",
            initial: "E",
            colorHex: "#0ea5e9",
            avatarURL: "",
            role: "editor"
        )
    }
}

private extension CurrentUserProfile {
    static func fixture(id: UUID, role: AppRole, permissions: Set<Permission>) -> CurrentUserProfile {
        CurrentUserProfile(
            id: id,
            email: "editor@example.com",
            fullName: "Editor",
            displayName: "Editor",
            shortName: "Editor",
            phone: "",
            role: role,
            rawRole: role.rawValue,
            department: "Team Marketing",
            avatarURL: "",
            editorCode: "dat",
            crewKey: "DAT",
            isEditorMember: true,
            isActive: true,
            permissionOverride: .roleDefault,
            permissions: permissions
        )
    }
}

private extension InternalNotification {
    static func fixture(id: String, readAt: String?) -> InternalNotification {
        InternalNotification(
            id: id,
            recipientId: UUID().uuidString,
            actorId: nil,
            type: "task_assigned",
            title: "Thông báo",
            body: "Nội dung",
            entityType: "video_task",
            entityId: UUID().uuidString,
            actionURL: nil,
            eventKey: nil,
            readAt: readAt,
            createdAt: "2026-08-08T00:00:00Z"
        )
    }
}

private extension ManagedUserProfile {
    static func fixture(permissionOverride: UserPermissionOverride) -> ManagedUserProfile {
        ManagedUserProfile(
            id: UUID().uuidString,
            email: "admin@example.com",
            fullName: "Admin Demo",
            displayName: "Admin",
            shortName: "Admin",
            phone: "",
            role: .admin,
            rawRole: "admin",
            department: "Team Marketing",
            avatarURL: "",
            editorCode: "admin",
            crewKey: "ADMIN",
            isEditorMember: true,
            isActive: true,
            permissionOverride: permissionOverride,
            createdAt: "2026-08-08T00:00:00Z",
            updatedAt: "2026-08-08T00:00:00Z"
        )
    }
}

private extension ShootSchedule {
    static func fixture(type: String, editorIds: [String], editorProfileIds: [String]) -> ShootSchedule {
        ShootSchedule(
            id: UUID().uuidString,
            date: "2026-08-07",
            type: type,
            crew: "",
            timeSlot: "",
            location: "",
            note: "",
            editorIds: editorIds,
            editorProfileIds: editorProfileIds
        )
    }
}

private final class TestOperationsRepository: OperationsRepositoryServing, @unchecked Sendable {
    var tasks: [VideoTask]
    var shoots: [ShootSchedule]
    var contentPlan: [ContentPlanItem]
    var editors: [EditorProfile]
    var tasksByStartDate: [String: [VideoTask]] = [:]
    var pausedVideoTaskFetchStartDates: Set<String> = []
    var pauseCreateVideoTask = false
    private var videoTaskFetchContinuations: [String: CheckedContinuation<Void, Never>] = [:]
    private var createVideoTaskContinuation: CheckedContinuation<Void, Never>?

    init(
        tasks: [VideoTask] = [],
        shoots: [ShootSchedule] = [],
        contentPlan: [ContentPlanItem] = [],
        editors: [EditorProfile] = []
    ) {
        self.tasks = tasks
        self.shoots = shoots
        self.contentPlan = contentPlan
        self.editors = editors
    }

    func fetchVideoTasks(range: MonthRange) async throws -> [VideoTask] {
        let result = tasksByStartDate[range.startDate] ?? tasks
        if pausedVideoTaskFetchStartDates.contains(range.startDate) {
            await withCheckedContinuation { continuation in
                videoTaskFetchContinuations[range.startDate] = continuation
            }
        }
        return result
    }

    func fetchShoots(range: MonthRange) async throws -> [ShootSchedule] { shoots }
    func fetchContentPlan(range: MonthRange) async throws -> [ContentPlanItem] { contentPlan }
    func fetchEditors() async throws -> [EditorProfile] { editors }

    func createVideoTask(_ data: VideoTaskFormData, userId: UUID?) async throws {
        guard pauseCreateVideoTask else { return }
        await withCheckedContinuation { continuation in
            createVideoTaskContinuation = continuation
        }
    }

    func updateVideoTask(_ task: VideoTask, data: VideoTaskFormData, userId: UUID?) async throws {}
    func deleteVideoTask(_ task: VideoTask) async throws {}
    func acceptLinkedVideoTask(_ task: VideoTask, data: LinkedTaskAcceptFormData) async throws {}
    func updateLinkedVideoTaskExecution(_ task: VideoTask, data: LinkedTaskExecutionFormData) async throws {}
    func completeLinkedVideoTask(_ task: VideoTask, data: LinkedTaskExecutionFormData) async throws {}
    func createShoot(_ data: ShootFormData) async throws {}
    func updateShoot(_ shoot: ShootSchedule, data: ShootFormData) async throws {}
    func deleteShoot(_ shoot: ShootSchedule) async throws {}
    func createContentPlan(_ data: ContentPlanFormData) async throws {}
    func updateContentPlan(_ item: ContentPlanItem, data: ContentPlanFormData, userId: UUID?) async throws {}
    func assignContentPlanEditor(_ item: ContentPlanItem, editorCode: String) async throws {}
    func deleteContentPlan(_ item: ContentPlanItem) async throws {}

    func resumeCreateVideoTask() {
        createVideoTaskContinuation?.resume()
        createVideoTaskContinuation = nil
    }

    func hasPendingVideoTaskFetch(startDate: String) -> Bool {
        videoTaskFetchContinuations[startDate] != nil
    }

    func resumeVideoTaskFetch(startDate: String) {
        videoTaskFetchContinuations[startDate]?.resume()
        videoTaskFetchContinuations[startDate] = nil
    }
}

private final class TestNotificationsRepository: NotificationsRepositoryServing, @unchecked Sendable {
    var notifications: [InternalNotification]
    var fetchCount = 0

    init(notifications: [InternalNotification] = []) {
        self.notifications = notifications
    }

    func fetchRecentNotifications(limit: Int) async throws -> [InternalNotification] {
        fetchCount += 1
        return Array(notifications.prefix(limit))
    }

    func markRead(notificationId: String) async throws {}
    func markAllRead() async throws {}
}

private final class TestAdminUserRepository: AdminUserRepositoryServing, @unchecked Sendable {
    var users: [ManagedUserProfile]
    var fetchCount = 0

    init(users: [ManagedUserProfile] = []) {
        self.users = users
    }

    func fetchUsers() async throws -> [ManagedUserProfile] {
        fetchCount += 1
        return users
    }
    func createUser(_ data: AdminUserFormData, actorId: UUID?) async throws {}
    func updateUser(_ profile: ManagedUserProfile, data: AdminUserFormData, actorId: UUID?) async throws {}
    func resetPassword(profile: ManagedUserProfile, password: String) async throws {}
    func deleteUser(_ profile: ManagedUserProfile) async throws {}
}
