import XCTest
@testable import CreativeHub

@MainActor
final class CreativeHubTests: XCTestCase {
    func testRouterDefaultsToOverview() {
        let router = AppRouter()

        XCTAssertEqual(router.selectedMain, .overview)
        XCTAssertTrue(router.path.isEmpty)
        XCTAssertTrue(router.isBottomNavigationVisible)
    }

    func testRegularTabsSelectCorrectDestination() {
        let router = AppRouter()

        router.selectMain(.video)
        XCTAssertEqual(router.selectedMain, .video)

        router.selectMain(.content)
        XCTAssertEqual(router.selectedMain, .content)

        router.selectMain(.members)
        XCTAssertEqual(router.selectedMain, .members)
    }

    func testCalendarCTASelectsCalendarDestination() {
        let router = AppRouter()

        router.selectMain(.calendar)

        XCTAssertEqual(router.selectedMain, .calendar)
        XCTAssertEqual(MainDestination.calendar.title, "Lịch quay")
    }

    func testMainDestinationMapping() {
        XCTAssertEqual(MainDestination.allCases, [.overview, .video, .calendar, .content, .members])
        XCTAssertEqual(MainDestination.regularTabs, [.overview, .video, .content, .members])
        XCTAssertEqual(MainDestination.overview.iconName, "chart.pie.fill")
        XCTAssertEqual(MainDestination.video.title, "Video")
        XCTAssertEqual(MainDestination.video.topBarTitle, "Video tháng")
        XCTAssertEqual(MainDestination.calendar.title, "Lịch quay")
        XCTAssertEqual(MainDestination.content.title, "Content")
        XCTAssertEqual(MainDestination.content.topBarTitle, "Content Plan")
        XCTAssertEqual(MainDestination.allCases.map(\.navigationAccessibilityIdentifier), [
            "navbar.overview",
            "navbar.video",
            "navbar.calendar",
            "navbar.content",
            "navbar.members"
        ])
    }

    func testRepeatedCurrentTabTapDoesNotCreateRoute() {
        let router = AppRouter()

        router.selectMain(.overview)

        XCTAssertEqual(router.selectedMain, .overview)
        XCTAssertTrue(router.path.isEmpty)
    }

    func testSecondaryRoutesHideBottomNavigation() {
        let router = AppRouter()

        router.pushSecondary(.notifications)

        XCTAssertFalse(router.isBottomNavigationVisible)
        router.pop()
        XCTAssertTrue(router.isBottomNavigationVisible)
    }

    func testSecondaryRoutesPreserveOriginWhenBackRestores() {
        let router = AppRouter()

        router.selectMain(.video)
        router.pushSecondary(.notifications)
        XCTAssertEqual(router.selectedMain, .video)
        XCTAssertFalse(router.isBottomNavigationVisible)

        router.pop()

        XCTAssertEqual(router.selectedMain, .video)
        XCTAssertTrue(router.isBottomNavigationVisible)
    }

    func testProfileRoutePreservesCalendarOrigin() {
        let router = AppRouter()

        router.selectMain(.calendar)
        router.pushSecondary(.profile)
        router.pop()

        XCTAssertEqual(router.selectedMain, .calendar)
        XCTAssertTrue(router.path.isEmpty)
    }

    func testModuleRoutesHideAndRestoreBottomNavigation() {
        let router = AppRouter()

        router.pushModule(.shootCreate)
        XCTAssertFalse(router.isBottomNavigationVisible)

        router.popToRoot()
        XCTAssertTrue(router.isBottomNavigationVisible)
        XCTAssertEqual(router.selectedMain, .overview)
    }

    func testModuleRouteBackRestoresSelectedTab() {
        let router = AppRouter()

        router.selectMain(.members)
        router.pushModule(.phase3Harness(origin: .members))
        XCTAssertFalse(router.isBottomNavigationVisible)

        router.pop()

        XCTAssertEqual(router.selectedMain, .members)
        XCTAssertTrue(router.isBottomNavigationVisible)
    }

    func testToolRevealStateIsIsolatedPerEligibleScreen() {
        let router = AppRouter()

        router.toggleToolReveal(for: .video)
        XCTAssertTrue(router.isToolRevealVisible(for: .video))
        XCTAssertFalse(router.isToolRevealVisible(for: .calendar))

        router.toggleToolReveal(for: .calendar)
        XCTAssertTrue(router.isToolRevealVisible(for: .video))
        XCTAssertTrue(router.isToolRevealVisible(for: .calendar))

        router.toggleToolReveal(for: .video)
        XCTAssertFalse(router.isToolRevealVisible(for: .video))
        XCTAssertTrue(router.isToolRevealVisible(for: .calendar))
    }

    func testOverviewDoesNotExposeToolReveal() {
        let router = AppRouter()

        router.toggleToolReveal(for: .overview)

        XCTAssertFalse(MainDestination.overview.canRevealTools)
        XCTAssertFalse(router.isToolRevealVisible(for: .overview))
    }

    func testEligibleScreensExposeToolAction() {
        XCTAssertEqual(MainDestination.allCases.filter(\.canRevealTools), [.video, .calendar, .content, .members])
    }

    func testPhase11Fix02RouterResetForLogoutClearsProfileRoute() {
        let router = AppRouter()

        router.selectMain(.video)
        router.toggleToolReveal(for: .video)
        router.pushSecondary(.profile)
        router.resetForLogout()

        XCTAssertEqual(router.selectedMain, .overview)
        XCTAssertNil(router.activeSecondary)
        XCTAssertNil(router.activeModule)
        XCTAssertTrue(router.path.isEmpty)
        XCTAssertTrue(router.isBottomNavigationVisible)
        XCTAssertFalse(router.isToolRevealVisible(for: .video))
    }

    func testPhase11Fix02RouterResetForLogoutClearsOtherSecondaryRoute() {
        let router = AppRouter()

        router.selectMain(.members)
        router.pushSecondary(.notifications)
        router.resetForLogout()

        XCTAssertEqual(router.selectedMain, .overview)
        XCTAssertNil(router.activeSecondary)
        XCTAssertTrue(router.path.isEmpty)
    }

    func testPhase11Fix02RouterResetForLogoutClearsModuleRouteAndRestoresOverview() {
        let router = AppRouter()

        router.selectMain(.calendar)
        router.pushModule(.shootEdit(id: "shoot-1"))
        router.resetForLogout()

        XCTAssertEqual(router.selectedMain, .overview)
        XCTAssertNil(router.activeModule)
        XCTAssertTrue(router.path.isEmpty)
    }

    func testPhase11Fix02NavigationResetDoesNotClearTimeScopePreferences() {
        let router = AppRouter()
        let store = InMemoryTimeScopePreferenceStore()
        let userID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        store.save(.month, userID: userID, module: .videoTasks)

        router.selectMain(.video)
        router.pushSecondary(.profile)
        router.resetForLogout()

        XCTAssertEqual(store.load(userID: userID, module: .videoTasks), .month)
    }

    func testToastPresentationMatchesCompactPrototypeContract() {
        XCTAssertFalse(CHToastPresentation.showsDefaultIcon)
        XCTAssertEqual(CHToastPresentation.horizontalPadding, 14)
        XCTAssertEqual(CHToastPresentation.verticalPadding, 10)
        XCTAssertEqual(CHToastPresentation.transitionDuration, 0.25)
        XCTAssertEqual(CHToastPresentation.hiddenOffsetY, 20)
    }

    func testToastPlacementUsesNavbarAndHiddenNavbarModes() {
        XCTAssertEqual(
            CHToastPlacement.bottomPadding(authentication: .authenticated, isBottomNavigationVisible: true),
            CHToastPresentation.visibleBottomPaddingWithNavbar
        )
        XCTAssertEqual(
            CHToastPlacement.bottomPadding(authentication: .authenticated, isBottomNavigationVisible: false),
            CHToastPresentation.visibleBottomPaddingWithoutNavbar
        )
        XCTAssertEqual(
            CHToastPlacement.bottomPadding(authentication: .signedOut, isBottomNavigationVisible: true),
            CHToastPresentation.visibleBottomPaddingWithoutNavbar
        )
    }

    func testSignedOutStateCannotBeAuthenticatedShell() {
        let state = AppState(authService: FakeAuthService())

        state.setAuthentication(.signedOut)

        XCTAssertNotEqual(state.authentication, .authenticated)
    }

    func testAuthenticationStateTransitions() {
        let state = AppState(authService: FakeAuthService())

        state.setAuthentication(.checkingSession)
        XCTAssertEqual(state.authentication, .checkingSession)

        state.setAuthentication(.authenticated)
        XCTAssertEqual(state.authentication, .authenticated)

        state.setAuthentication(.sessionExpired)
        XCTAssertEqual(state.authentication, .sessionExpired)
    }

    func testBootstrapWithoutSessionShowsSignedOut() async {
        let fake = FakeAuthService()
        fake.restoredSessionResult = .success(nil)
        let state = AppState(authService: fake)

        await state.start()

        XCTAssertEqual(state.authentication, .signedOut)
        XCTAssertEqual(state.currentUser, .empty)
    }

    func testBootstrapWithStoredSessionEntersAuthenticatedShell() async {
        let fake = FakeAuthService()
        fake.restoredSessionResult = .success(.sample)
        fake.bootstrapResult = .success(.sample)
        let state = AppState(authService: fake)

        await state.start()

        XCTAssertEqual(state.authentication, .authenticated)
        XCTAssertEqual(state.currentUser.displayName, "Dat")
        XCTAssertEqual(state.currentUser.email, "dat@example.com")
    }

    func testBootstrapMissingConfigurationShowsLoadError() async {
        let fake = FakeAuthService()
        fake.isConfigured = false
        let state = AppState(authService: fake)

        await state.start()

        XCTAssertEqual(state.authentication, .loadError)
    }

    func testBootstrapOfflineShowsOfflineWithoutServiceCall() async {
        let fake = FakeAuthService()
        let state = AppState(authService: fake, networkMonitor: StaticNetworkMonitor(isConnected: false))

        await state.start()

        XCTAssertEqual(state.authentication, .offline)
        XCTAssertEqual(fake.restoreCallCount, 0)
    }

    func testExpiredStoredSessionShowsSessionExpiredAndClearsUser() async {
        let fake = FakeAuthService()
        fake.restoredSessionResult = .failure(AuthServiceError.sessionExpired)
        let state = AppState(authService: fake)
        state.currentUser = .preview

        await state.start()

        XCTAssertEqual(state.authentication, .sessionExpired)
        XCTAssertEqual(state.currentUser, .empty)
    }

    func testBootstrapBackendErrorShowsLoadError() async {
        let fake = FakeAuthService()
        fake.restoredSessionResult = .failure(AuthServiceError.backend("profiles failed"))
        let state = AppState(authService: fake)

        await state.start()

        XCTAssertEqual(state.authentication, .loadError)
    }

    func testBootstrapForbiddenShowsForbiddenAndClearsUser() async {
        let fake = FakeAuthService()
        fake.restoredSessionResult = .success(.sample)
        fake.bootstrapResult = .failure(AuthServiceError.forbidden)
        let state = AppState(authService: fake)
        state.currentUser = .preview

        await state.start()

        XCTAssertEqual(state.authentication, .forbidden)
        XCTAssertEqual(state.currentUser, .empty)
    }

    func testSignInRequiresEmailAndPassword() async {
        let fake = FakeAuthService()
        let state = AppState(authService: fake)

        await state.signIn()

        XCTAssertEqual(state.authentication, .checkingSession)
        XCTAssertEqual(state.loginError, "Vui lòng nhập email và mật khẩu.")
        XCTAssertEqual(fake.signInCallCount, 0)
    }

    func testInvalidLoginStaysOnLoginWithNativeErrorCopy() async {
        let fake = FakeAuthService()
        fake.signInResult = .failure(AuthServiceError.invalidCredentials)
        let state = AppState(authService: fake)
        state.loginEmail = "dat@example.com"
        state.loginPassword = "bad-password"

        await state.signIn()

        XCTAssertEqual(state.authentication, .signedOut)
        XCTAssertEqual(state.loginError, AppState.invalidCredentialsMessage)
    }

    func testLoginEmailNotConfirmedShowsInlineError() async {
        let fake = FakeAuthService()
        fake.signInResult = .failure(AuthServiceError.emailNotConfirmed)
        let state = AppState(authService: fake)
        state.loginEmail = "dat@example.com"
        state.loginPassword = "password"

        await state.signIn()

        XCTAssertEqual(state.authentication, .signedOut)
        XCTAssertEqual(state.loginError, "Email chưa được xác nhận. Vui lòng kiểm tra hộp thư.")
    }

    func testSignInSuccessBootstrapsProfileAndClearsPassword() async {
        let fake = FakeAuthService()
        fake.signInResult = .success(.sample)
        fake.bootstrapResult = .success(.sample)
        let state = AppState(authService: fake)
        state.loginEmail = "dat@example.com"
        state.loginPassword = "password"

        await state.signIn()

        XCTAssertEqual(state.authentication, .authenticated)
        XCTAssertEqual(state.currentUser.displayName, "Dat")
        XCTAssertEqual(state.loginPassword, "")
    }

    func testSignInForbiddenShowsForbiddenAndClearsPassword() async {
        let fake = FakeAuthService()
        fake.signInResult = .success(.sample)
        fake.bootstrapResult = .failure(AuthServiceError.forbidden)
        let state = AppState(authService: fake)
        state.loginEmail = "dat@example.com"
        state.loginPassword = "password"

        await state.signIn()

        XCTAssertEqual(state.authentication, .forbidden)
        XCTAssertEqual(state.loginPassword, "")
    }

    func testRetryBootstrapReusesStoredSession() async throws {
        let fake = FakeAuthService()
        fake.restoredSessionResult = .success(.sample)
        fake.bootstrapResult = .success(.sample)
        let state = AppState(authService: fake)
        state.setAuthentication(.loadError)

        state.retryBootstrap()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(state.authentication, .authenticated)
        XCTAssertEqual(fake.restoreCallCount, 1)
    }

    func testReturnToLoginSignsOutAndClearsSensitiveState() async throws {
        let fake = FakeAuthService()
        let state = AppState(authService: fake)
        state.currentUser = .preview
        state.loginPassword = "secret"

        state.returnToLogin()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(state.authentication, .signedOut)
        XCTAssertEqual(state.currentUser, .empty)
        XCTAssertEqual(state.loginPassword, "")
        XCTAssertEqual(fake.signOutCallCount, 1)
    }

    func testPhase11Fix03SignOutFailureKeepsAuthenticatedState() async {
        let fake = FakeAuthService()
        fake.signOutResult = .failure(AuthServiceError.backend("network"))
        let state = AppState(authService: fake)
        state.authentication = .authenticated
        state.currentUser = .preview
        state.loginPassword = "secret"

        let signedOut = await state.signOutAndReturnToLogin()

        XCTAssertFalse(signedOut)
        XCTAssertEqual(state.authentication, .authenticated)
        XCTAssertEqual(state.currentUser, .preview)
        XCTAssertEqual(state.loginPassword, "secret")
        XCTAssertEqual(fake.signOutCallCount, 1)
    }

    func testForgotPasswordShowsDeferredInfoWithoutBackendRequest() {
        let fake = FakeAuthService()
        let state = AppState(authService: fake)
        state.authentication = .signedOut
        state.loginEmail = "dat@example.com"
        state.loginPassword = "secret"
        state.loginError = AppState.invalidCredentialsMessage

        state.requestPasswordReset()

        XCTAssertEqual(state.authentication, .signedOut)
        XCTAssertEqual(state.loginEmail, "dat@example.com")
        XCTAssertEqual(state.loginPassword, "secret")
        XCTAssertEqual(state.loginError, AppState.invalidCredentialsMessage)
        XCTAssertEqual(state.passwordRecoveryInfo?.title, "Khôi phục mật khẩu")
        XCTAssertEqual(
            state.passwordRecoveryInfo?.message,
            "Tính năng khôi phục mật khẩu chưa được cấu hình trên hệ thống. Vui lòng liên hệ quản trị viên để được hỗ trợ."
        )
        XCTAssertEqual(fake.resetCallCount, 0)
    }

    func testOverviewMonthBoundariesAcrossMonthLengths() {
        XCTAssertEqual(OverviewMonth(year: 2026, month: 4).startISODate, "2026-04-01")
        XCTAssertEqual(OverviewMonth(year: 2026, month: 4).endISODate, "2026-04-30")
        XCTAssertEqual(OverviewMonth(year: 2026, month: 8).endISODate, "2026-08-31")
        XCTAssertEqual(OverviewMonth(year: 2026, month: 12).endDateExclusive, OverviewMonth(year: 2027, month: 1).startDate)
    }

    func testOverviewLeapYearFebruaryAndAxisLabels() {
        XCTAssertEqual(OverviewMonth(year: 2024, month: 2).daysInMonth, 29)
        XCTAssertEqual(OverviewMonth(year: 2024, month: 2).axisLabels, ["01", "08", "15", "22", "29"])
        XCTAssertEqual(OverviewMonth(year: 2026, month: 2).daysInMonth, 28)
        XCTAssertEqual(OverviewMonth(year: 2026, month: 2).axisLabels, ["01", "08", "15", "22", "28"])
    }

    func testOverviewZeroDataCompletionAndDistribution() {
        let dashboard = OverviewAggregator.aggregate(
            rawData: OverviewRawData(tasks: [], shoots: [], editors: []),
            month: OverviewMonth(year: 2026, month: 8)
        )

        XCTAssertEqual(dashboard.totalVideos, 0)
        XCTAssertEqual(dashboard.completedVideos, 0)
        XCTAssertEqual(dashboard.completionPercent, 0)
        XCTAssertEqual(dashboard.remainingVideos, 0)
        XCTAssertEqual(dashboard.shootCount, 0)
        XCTAssertEqual(dashboard.shootLoadTrack, .neutral)
        XCTAssertNil(dashboard.shootLoadTrack.fillRatio)
        XCTAssertTrue(dashboard.teamOrders.isEmpty)
        XCTAssertTrue(dashboard.isZeroData)
    }

    func testOverviewCompletedCountUsesVerifiedStatusSemantics() {
        let month = OverviewMonth(year: 2026, month: 8)
        let rows = [
            overviewTask(id: "1", status: "Đã xong", airDate: "2026-08-01"),
            overviewTask(id: "2", status: "Đang làm", airDate: "2026-08-02"),
            overviewTask(id: "3", status: "Chờ", airDate: "2026-08-03")
        ]

        let dashboard = OverviewAggregator.aggregate(rawData: OverviewRawData(tasks: rows, shoots: [], editors: []), month: month)

        XCTAssertEqual(dashboard.totalVideos, 3)
        XCTAssertEqual(dashboard.completedVideos, 1)
        XCTAssertEqual(dashboard.remainingVideos, 2)
        XCTAssertEqual(dashboard.completionPercent, 33)
    }

    func testOverviewUsesEffectiveLinkedAirDateForMonthlyMembership() {
        let month = OverviewMonth(year: 2026, month: 8)
        let rows = [
            overviewTask(id: "linked", status: "Đã xong", airDate: "2026-07-31", linkedAirDate: "2026-08-01"),
            overviewTask(id: "outside", status: "Đã xong", airDate: "2026-08-01", linkedAirDate: "2026-09-01")
        ]

        let dashboard = OverviewAggregator.aggregate(rawData: OverviewRawData(tasks: rows, shoots: [], editors: []), month: month)

        XCTAssertEqual(dashboard.totalVideos, 1)
        XCTAssertEqual(dashboard.completedVideos, 1)
    }

    func testOverviewShootCountExcludesLivestream() {
        let month = OverviewMonth(year: 2026, month: 8)
        let shoots = [
            overviewShoot(id: "1", date: "2026-08-01", type: "lichquay"),
            overviewShoot(id: "2", date: "2026-08-02", type: "livestream"),
            overviewShoot(id: "3", date: "2026-09-01", type: "lichquay")
        ]

        let dashboard = OverviewAggregator.aggregate(rawData: OverviewRawData(tasks: [], shoots: shoots, editors: []), month: month)

        XCTAssertEqual(dashboard.shootCount, 1)
        XCTAssertEqual(dashboard.shootLoadTrack, .neutral)
        XCTAssertNil(dashboard.shootLoadTrack.fillRatio)
    }

    func testOverviewTeamOrderGroupingAndZeroDistribution() {
        let month = OverviewMonth(year: 2026, month: 8)
        let rows = [
            overviewTask(id: "1", orderTeam: "BRAND", airDate: "2026-08-01"),
            overviewTask(id: "2", orderTeam: "DIGITAL", airDate: "2026-08-02"),
            overviewTask(id: "3", orderTeam: "BRAND", airDate: "2026-08-03")
        ]

        let dashboard = OverviewAggregator.aggregate(rawData: OverviewRawData(tasks: rows, shoots: [], editors: []), month: month)

        XCTAssertEqual(dashboard.teamOrders.map(\.label), ["BRAND", "DIGITAL"])
        XCTAssertEqual(dashboard.teamOrders.map(\.count), [2, 1])
        XCTAssertTrue(OverviewAggregator.makeTeamOrders(from: []).isEmpty)
        XCTAssertEqual(OverviewTeamOrder(label: "EMPTY", count: 5).segmentRatio(total: 0), 0)
        XCTAssertEqual(dashboard.teamOrders[0].segmentRatio(total: 3), 2.0 / 3.0, accuracy: 0.0001)
    }

    func testOverviewTeamOrderPreservesExtraRealGroups() {
        let month = OverviewMonth(year: 2026, month: 8)
        let rows = [
            overviewTask(id: "1", orderTeam: "partner", airDate: "2026-08-01"),
            overviewTask(id: "2", orderTeam: "BRAND", airDate: "2026-08-02"),
            overviewTask(id: "3", orderTeam: "partner", airDate: "2026-08-03")
        ]

        let dashboard = OverviewAggregator.aggregate(rawData: OverviewRawData(tasks: rows, shoots: [], editors: []), month: month)

        XCTAssertEqual(dashboard.teamOrders.map(\.label), ["PARTNER", "BRAND"])
        XCTAssertEqual(dashboard.teamOrders.map(\.count), [2, 1])
    }

    func testOverviewEditorWorkloadUsesProfileFallbackAndMissingAvatar() {
        let month = OverviewMonth(year: 2026, month: 8)
        let editor = OverviewEditorRow(id: "profile-1", editorCode: "dat", name: "Đoàn Quốc Đạt", shortName: "Đạt Đoàn", initials: "Đ", avatarURL: nil, colorHex: "#0EA5E9")
        let rows = [
            overviewTask(id: "1", airDate: "2026-08-01", editorCode: "dat", editorProfileID: "profile-1"),
            overviewTask(id: "2", airDate: "2026-08-08", editorCode: "missing", editorProfileID: nil)
        ]

        let dashboard = OverviewAggregator.aggregate(rawData: OverviewRawData(tasks: rows, shoots: [], editors: [editor]), month: month)

        XCTAssertEqual(dashboard.editorWorkload.first?.shortName, "Đạt Đoàn")
        XCTAssertNil(dashboard.editorWorkload.first?.avatarURL)
        XCTAssertTrue(dashboard.editorWorkload.contains { $0.id == "missing" && $0.shortName == "MISSING" })
    }

    func testOverviewChartAndWorkloadBucketsAreRealDateDerived() {
        let month = OverviewMonth(year: 2026, month: 8)
        let rows = [
            overviewTask(id: "1", status: "Đã xong", airDate: "2026-08-01", editorCode: "dat"),
            overviewTask(id: "2", status: "Đã xong", airDate: "2026-08-15", editorCode: "dat"),
            overviewTask(id: "3", status: "Đã xong", airDate: "2026-08-31", editorCode: "dat")
        ]

        let dashboard = OverviewAggregator.aggregate(rawData: OverviewRawData(tasks: rows, shoots: [], editors: []), month: month)

        XCTAssertEqual(dashboard.chartPoints.first?.value, 1)
        XCTAssertEqual(dashboard.chartPoints[14].value, 2)
        XCTAssertEqual(dashboard.chartPoints.last?.value, 3)
        XCTAssertEqual(dashboard.editorWorkload.first?.buckets.reduce(0, +), 3)
    }

    func testOverviewTrackSemanticsExposeNoFillForNeutralShootLoad() {
        XCTAssertNil(OverviewTrackSemantics.neutral.fillRatio)
        XCTAssertEqual(OverviewTrackSemantics.ratio(-0.2).fillRatio, 0)
        XCTAssertEqual(OverviewTrackSemantics.ratio(1.2).fillRatio, 1)
        XCTAssertEqual(OverviewTrackSemantics.ratio(0.49).fillRatio, 0.49)
    }

    func testOverviewViewModelRetryStateAndRefreshStaleData() async {
        let month = OverviewMonth(year: 2026, month: 8)
        let provider = MutableOverviewProvider(results: [
            .failure(OverviewRepositoryError.configurationMissing),
            .success(OverviewRawData(tasks: [overviewTask(id: "1", status: "Đã xong", airDate: "2026-08-01")], shoots: [], editors: [])),
            .failure(OverviewRepositoryError.configurationMissing)
        ])
        let viewModel = OverviewViewModel(provider: provider, month: month)

        await viewModel.loadIfNeeded()
        XCTAssertNotNil(viewModel.state.errorMessage)

        await viewModel.retry()
        XCTAssertEqual(viewModel.state.dashboard?.totalVideos, 1)

        await viewModel.refresh()
        XCTAssertEqual(viewModel.state.dashboard?.totalVideos, 1)
        XCTAssertNotNil(viewModel.state.errorMessage)
    }

    func testOverviewProductionProviderDoesNotDefaultToFixture() {
        XCTAssertTrue(OverviewProviderFactory.makeProvider().usesProductionData)
    }

    func testOverviewFixtureProviderRequiresExplicitDebugSelection() async throws {
        let month = OverviewMonth(year: 2026, month: 8)
        let provider = OverviewFixtureProvider(fixture: .visual)
        let rawData = try await provider.fetchOverviewRawData(month: month)
        let dashboard = OverviewAggregator.aggregate(rawData: rawData, month: month)

        XCTAssertFalse(provider.usesProductionData)
        XCTAssertEqual(dashboard.totalVideos, 43)
        XCTAssertEqual(dashboard.completedVideos, 21)
    }

    func testCalendarProductionProviderDoesNotDefaultToFixture() {
        XCTAssertTrue(CalendarProviderFactory.makeProvider().usesProductionData)
    }

    func testCalendarFixtureProviderRequiresExplicitDebugSelection() async throws {
        let provider = CalendarFixtureProvider(mode: .full)
        let rows = try await provider.fetchShoots(startDate: "2026-08-01", endDate: "2026-08-31")

        XCTAssertFalse(provider.usesProductionData)
        XCTAssertTrue(rows.contains { $0.type == .livestream })
        XCTAssertTrue(rows.contains { $0.type == .lichquay })
        XCTAssertTrue(rows.contains { $0.type == .onset })
        XCTAssertTrue(rows.contains { $0.type == .other })
    }

    func testCalendarWeekStartsMondayContainsSevenDatesAndSundayState() {
        let selected = CalendarDateFormatter.date(from: "2026-08-17")!
        let week = CalendarDateFormatter.week(containing: selected)

        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first?.isoDate, "2026-08-17")
        XCTAssertEqual(week.first?.weekdayLabel, "T2")
        XCTAssertEqual(week.last?.isoDate, "2026-08-23")
        XCTAssertTrue(week.last?.isSunday == true)
        XCTAssertTrue(week.first?.isSelected == true)
    }

    func testCalendarSelectedDateMapsToCreateDefaultDate() {
        let date = CalendarDateFormatter.date(from: "2026-08-19")!
        let form = CalendarFormData.createDefault(date: date)

        XCTAssertEqual(form.date, "2026-08-19")
        XCTAssertEqual(form.type, .lichquay)
        XCTAssertEqual(form.time, "ALL MORNING")
    }

    func testCalendarShootTypeAndFilterMappings() {
        XCTAssertEqual(CalendarShootType.allCases.map(\.rawValue), ["livestream", "lichquay", "onset", "other"])
        XCTAssertEqual(CalendarShootFilter.allCases.map(\.rawValue), ["all", "livestream", "lichquay", "onset", "other"])
        XCTAssertNil(CalendarShootFilter.all.type)
        XCTAssertEqual(CalendarShootFilter.onset.type, .onset)
    }

    func testCalendarAgendaSortFilterAndContentTitleMapping() async {
        let provider = TestCalendarProvider(
            shoots: [
                calendarShoot(id: "00000000-0000-0000-0000-000000000012", date: "2026-08-20", type: .onset, content: "On set real content"),
                calendarShoot(id: "00000000-0000-0000-0000-000000000011", date: "2026-08-05", type: .lichquay, content: "Content note title")
            ],
            editors: []
        )
        let viewModel = CalendarViewModel(provider: provider, initialDate: CalendarDateFormatter.date(from: "2026-08-17")!, timeScope: .month)

        await viewModel.load()
        XCTAssertEqual(viewModel.visibleShoots.map(\.content), ["Content note title", "On set real content"])

        viewModel.filter = .onset
        XCTAssertEqual(viewModel.visibleShoots.map(\.type), [.onset])
        XCTAssertEqual(viewModel.visibleShoots.first?.content, "On set real content")
    }

    func testCalendarDisplayCrewCombinesEditorsAndFreeCrew() {
        let shoot = calendarShoot(
            id: "00000000-0000-0000-0000-000000000013",
            editorCodes: ["dat", "minh"],
            editorLabels: ["ĐẠT", "MINH"],
            crew: "BUMI"
        )

        XCTAssertEqual(shoot.displayCrew, "ĐẠT - MINH - BUMI")
        XCTAssertEqual(shoot.place, "SHOWROOM HÒA BÌNH")
    }

    func testCalendarCanonicalEditorCrewLabelMapperMatchesWebSource() {
        XCTAssertEqual(CalendarEditorCrewLabelMapper.label(editorCode: "dat", fullName: "Đoàn Quốc Đạt", displayName: nil, shortName: "Đạt Đoàn"), "ĐẠT")
        XCTAssertEqual(CalendarEditorCrewLabelMapper.label(editorCode: "minh", fullName: "Hữu Minh", displayName: nil, shortName: "Hữu Minh"), "MINH")
        XCTAssertEqual(CalendarEditorCrewLabelMapper.label(editorCode: "hai", fullName: "Thanh Hải", displayName: nil, shortName: "Thanh Hải"), "HẢI")
        XCTAssertEqual(CalendarEditorCrewLabelMapper.label(editorCode: "quang", fullName: "Nguyễn Văn Quang", displayName: nil, shortName: nil), "QUANG")
        XCTAssertEqual(CalendarEditorCrewLabelMapper.combine(editorLabels: ["ĐẠT", "MINH"], crew: "BUMI"), "ĐẠT - MINH - BUMI")
    }

    func testCalendarFixtureMutationPreservesCanonicalAgendaCrewLabels() async throws {
        let provider = CalendarFixtureProvider(mode: .full)
        let range = CalendarDateRange(startDate: "2026-08-01", endDate: "2026-08-31")
        let targetID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let before = try await provider.fetchShoots(startDate: range.startDate, endDate: range.endDate)
            .first { $0.id == targetID }
        XCTAssertEqual(before?.displayCrew, "ĐẠT - MINH - BUMI")

        try await provider.updateShoot(id: targetID, data: CalendarFormData(
            date: "2026-08-05",
            type: .lichquay,
            time: "ALL MORNING",
            place: "SHOWROOM HÒA BÌNH",
            editorCodes: ["dat", "minh"],
            crew: "BUMI",
            content: "Kịch bản showroom Hòa Bình - hiểu đúng nệm",
            note: "Ghi chú QA"
        ))

        let afterUpdate = try await provider.fetchShoots(startDate: range.startDate, endDate: range.endDate)
            .first { $0.id == targetID }
        XCTAssertEqual(afterUpdate?.displayCrew, "ĐẠT - MINH - BUMI")

        try await provider.createShoot(CalendarFormData(
            date: "2026-08-17",
            type: .lichquay,
            time: "ALL MORNING",
            place: "Studio",
            editorCodes: ["dat", "minh"],
            crew: "BUMI",
            content: "Nội dung",
            note: ""
        ))
        let created = try await provider.fetchShoots(startDate: range.startDate, endDate: range.endDate)
            .first { $0.id == UUID(uuidString: "00000000-0000-0000-0000-000000000099")! }
        XCTAssertEqual(created?.displayCrew, "ĐẠT - MINH - BUMI")
    }

    func testCalendarEditorPickerDisplayNameIsIndependentFromCompactAgendaLabel() {
        let option = CalendarEditorOption(
            editorCode: "dat",
            profileID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Đoàn Quốc Đạt",
            shortName: "Đạt Đoàn",
            initials: "Đ",
            colorHex: "#0EA5E9",
            avatarURL: nil
        )

        XCTAssertEqual(option.shortName, "Đạt Đoàn")
        XCTAssertEqual(CalendarEditorCrewLabelMapper.label(for: option), "ĐẠT")
        XCTAssertNotEqual(option.shortName.uppercased(), CalendarEditorCrewLabelMapper.label(for: option))
    }

    func testCalendarEditorCodeAndProfileUUIDStayDistinct() throws {
        let form = CalendarFormData(
            date: "2026-08-17",
            type: .lichquay,
            time: "ALL MORNING",
            place: "Studio",
            editorCodes: ["dat", "minh"],
            crew: "",
            content: "Nội dung",
            note: "Ghi chú"
        )
        let profileUUID = "11111111-1111-1111-1111-111111111111"
        let params = try CalendarRPCContract.createParams(data: form)

        XCTAssertEqual(params["p_editor_codes"], "dat,minh")
        XCTAssertFalse(params["p_editor_codes"]?.contains(profileUUID) == true)
    }

    func testCalendarCreateUpdateDeleteRPCParamsAndNoteBehavior() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000055")!
        let form = CalendarFormData(
            date: "2026-08-17",
            type: .onset,
            time: "13:30",
            place: "ON SET TIDO",
            editorCodes: [" HAI "],
            crew: "BUMI",
            content: "Nội dung thật",
            note: "Ghi chú riêng"
        )

        let create = try CalendarRPCContract.createParams(data: form)
        let update = try CalendarRPCContract.updateParams(id: id, data: form)
        let payload = try CalendarPayload(data: form)

        XCTAssertEqual(create["p_shoot_date"], "2026-08-17")
        XCTAssertEqual(create["p_shoot_type"], "onset")
        XCTAssertEqual(create["p_editor_codes"], "hai")
        XCTAssertNil(create["shoot_note"])
        XCTAssertEqual(update["p_shoot_id"], id.uuidString)
        XCTAssertEqual(CalendarRPCContract.deleteParams(id: id), ["p_shoot_id": id.uuidString])
        XCTAssertEqual(payload.shootNote, "Ghi chú riêng")
    }

    func testCalendarValidationCopies() {
        XCTAssertThrowsError(try CalendarPayload(data: CalendarFormData(date: "2026-02-31", type: .lichquay, time: "", place: "Studio", editorCodes: [], crew: "", content: "Nội dung", note: ""))) { error in
            XCTAssertEqual((error as? CalendarValidationError)?.errorDescription, "Ngày quay không hợp lệ.")
        }
        XCTAssertThrowsError(try CalendarPayload(data: CalendarFormData(date: "2026-08-17", type: .lichquay, time: "", place: "", editorCodes: [], crew: "", content: "Nội dung", note: ""))) { error in
            XCTAssertEqual((error as? CalendarValidationError)?.errorDescription, "Vui lòng nhập địa điểm lịch quay.")
        }
        XCTAssertThrowsError(try CalendarPayload(data: CalendarFormData(date: "2026-08-17", type: .lichquay, time: "", place: "Studio", editorCodes: [], crew: "", content: "", note: ""))) { error in
            XCTAssertEqual((error as? CalendarValidationError)?.errorDescription, "Vui lòng nhập nội dung lịch quay.")
        }
    }

    func testCalendarPermissionsCreateUpdateDeleteAndReadOnly() async {
        let fake = FakeAuthService()
        fake.restoredSessionResult = .success(.sample)
        fake.bootstrapResult = .success(.sampleContentCreator)
        let state = AppState(authService: fake)

        await state.start()

        XCTAssertTrue(state.can(.shootsCreate))
        XCTAssertTrue(state.can(.shootsUpdate))
        XCTAssertTrue(state.can(.shootsDelete))

        let readonly = AppState(authService: fake)
        readonly.setAuthentication(.authenticated)
        readonly.currentUser = CurrentUserSummary(displayName: "Read", email: "read@test", avatarURL: nil)
        // View-only behavior is also covered through custom bootstrapping below.
        XCTAssertFalse(CalendarPermissions(canCreate: false, canUpdate: false, canDelete: false).canUpdate)
    }

    func testCalendarViewModelReadOnlyDetailOpensFromCard() {
        let shoot = calendarShoot(id: "00000000-0000-0000-0000-000000000014")
        let viewModel = CalendarViewModel(provider: TestCalendarProvider(shoots: [shoot], editors: []), initialDate: shoot.date)

        viewModel.open(shoot: shoot, canUpdate: false)

        XCTAssertEqual(viewModel.moduleMode?.title, "Chi tiết lịch quay")
        XCTAssertFalse(viewModel.moduleMode?.isEditable == true)
    }

    func testCalendarLoadErrorRetryAndFilteredEmptyState() async {
        let provider = TestCalendarProvider(
            shoots: [calendarShoot(id: "00000000-0000-0000-0000-000000000015", type: .lichquay)],
            editors: [],
            loadResults: [.failure(CalendarRepositoryError.backend("Không thể tải lịch quay")), .success]
        )
        let viewModel = CalendarViewModel(provider: provider, initialDate: CalendarDateFormatter.date(from: "2026-08-17")!, timeScope: .month)

        await viewModel.load()
        if case .failed(let message, _) = viewModel.loadState {
            XCTAssertEqual(message, "Không thể tải lịch quay")
        } else {
            XCTFail("Expected load failure")
        }

        await viewModel.retry()
        viewModel.filter = .onset
        XCTAssertTrue(viewModel.monthHasShoots)
        XCTAssertTrue(viewModel.visibleShoots.isEmpty)
    }

    func testCalendarMutationFailureKeepsModuleOpenAndSuccessReloads() async {
        let shoot = calendarShoot(id: "00000000-0000-0000-0000-000000000016")
        let provider = TestCalendarProvider(shoots: [shoot], editors: [], mutationResult: .failure(CalendarRepositoryError.backend("Mutation failed")))
        let viewModel = CalendarViewModel(provider: provider, initialDate: shoot.date)

        await viewModel.load()
        viewModel.open(shoot: shoot, canUpdate: true)
        let failed = await viewModel.save()

        XCTAssertFalse(failed)
        XCTAssertNotNil(viewModel.moduleMode)
        XCTAssertEqual(viewModel.modalError, "Mutation failed")

        provider.mutationResult = .success(())
        viewModel.formData.content = "Updated content"
        let saved = await viewModel.save()

        XCTAssertTrue(saved)
        XCTAssertEqual(provider.reloadCount, 2)
    }

    func testCalendarToastAndNavbarRegressionContract() {
        let router = AppRouter()
        router.selectMain(.calendar)
        router.pushModule(.shootCreate)

        XCTAssertFalse(router.isBottomNavigationVisible)
        router.pop()
        XCTAssertEqual(router.selectedMain, .calendar)
        XCTAssertTrue(router.isBottomNavigationVisible)
        XCTAssertEqual(CHToastPlacement.bottomPadding(authentication: .authenticated, isBottomNavigationVisible: true), 96)
    }

    func testPhase6VideoTaskProductContractsMatchLocalWeb() {
        XCTAssertEqual(VideoTaskStatus.allCases.map(\.rawValue), ["Chờ", "Đang làm", "Đã xong"])
        XCTAssertFalse(VideoTaskStatus.allCases.map(\.rawValue).contains("Đang dựng"))
        XCTAssertEqual(VideoTaskCategory.allCases.map(\.rawValue), ["Video dài", "Motion", "Ads"])
        XCTAssertEqual(VideoTaskPriority.allCases.map(\.rawValue), ["", "Gấp"])
        XCTAssertEqual(VideoTaskConstants.orderTeams, ["BRAND", "DIGITAL", "ECOM", "HR", "ISD", "IT", "CS", "GT", "PUR"])
        XCTAssertTrue(VideoTaskURLValidator.isSafeHTTPURL("https://example.com/file"))
        XCTAssertFalse(VideoTaskURLValidator.isSafeHTTPURL("ftp://example.com/file"))
        XCTAssertFalse(VideoTaskURLValidator.isSafeHTTPURL("#"))
    }

    func testPhase6StandaloneDefaultsValidationAndPayload() async throws {
        let editor = videoEditor(code: "dat")
        let defaults = VideoTaskFormData.createDefault(editors: [editor])
        XCTAssertEqual(defaults.status, .waiting)
        XCTAssertEqual(defaults.category, .longForm)
        XCTAssertEqual(defaults.priority, .normal)
        XCTAssertEqual(defaults.orderTeam, "BRAND")
        XCTAssertEqual(defaults.editorCode, "dat")
        XCTAssertEqual(defaults.receiveDate, "")

        do {
            _ = try await VideoTaskPayload.make(data: defaults)
            XCTFail("Expected missing title validation")
        } catch {
            XCTAssertEqual((error as? VideoTaskValidationError)?.errorDescription, "Vui lòng nhập tên video.")
        }

        var valid = defaults
        valid.title = "Video QA"
        valid.receiveDate = "2026-08-10"
        valid.returnDate = "2026-08-09"
        do {
            _ = try await VideoTaskPayload.make(data: valid)
            XCTFail("Expected return-before-receive validation")
        } catch {
            XCTAssertEqual((error as? VideoTaskValidationError), .returnBeforeReceive)
        }

        valid.returnDate = "2026-08-12"
        valid.airDate = "2026-08-15"
        valid.resultLink = "https://example.com/result"
        let payload = try await VideoTaskPayload.make(data: valid, userID: editor.profileID, includeCreatedBy: true)
        XCTAssertEqual(payload.title, "Video QA")
        XCTAssertNil(payload.editorID)
        XCTAssertEqual(payload.createdBy, editor.profileID)
        XCTAssertEqual(payload.resultLink, "https://example.com/result")
    }

    func testPhase6LinkedFieldStateAndAdminOverrideRestrictions() {
        let current = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let waiting = videoTask(id: "00000000-0000-0000-0000-000000000641", contentPlanID: "90000000-0000-0000-0000-000000000641", editorProfileID: current, status: .waiting)
        let assignedOther = videoTask(id: "00000000-0000-0000-0000-000000000642", contentPlanID: "90000000-0000-0000-0000-000000000642", editorProfileID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, status: .waiting)
        let doing = videoTask(id: "00000000-0000-0000-0000-000000000643", contentPlanID: "90000000-0000-0000-0000-000000000643", editorProfileID: current, status: .inProgress)
        let userPerms = VideoTaskPermissions(canCreate: true, canUpdate: true, canDelete: true, isAdmin: false, currentProfileID: current)

        let accept = VideoTaskFieldState.resolve(task: waiting, permissions: userPerms, readOnly: false)
        XCTAssertTrue(accept.canAccept)
        XCTAssertFalse(accept.canUseGenericSave)
        XCTAssertFalse(accept.canEditStatus)
        XCTAssertFalse(accept.canEditTitle)
        XCTAssertTrue(accept.canEditReceiveDate)

        let other = VideoTaskFieldState.resolve(task: assignedOther, permissions: userPerms, readOnly: false)
        XCTAssertFalse(other.canAccept)
        XCTAssertFalse(other.canComplete)
        XCTAssertFalse(other.canUseGenericSave)

        let complete = VideoTaskFieldState.resolve(task: doing, permissions: userPerms, readOnly: false)
        XCTAssertTrue(complete.canSaveExecution)
        XCTAssertTrue(complete.canComplete)
        XCTAssertTrue(complete.canEditResultLink)
        XCTAssertFalse(complete.canEditAirDate)

        let admin = VideoTaskFieldState.resolve(task: doing, permissions: VideoTaskPermissions(canCreate: true, canUpdate: true, canDelete: true, isAdmin: true, currentProfileID: current), readOnly: false)
        XCTAssertTrue(admin.canUseGenericSave)
        XCTAssertTrue(admin.canEditStatus)
        XCTAssertTrue(admin.canEditOrderTeam)
        XCTAssertFalse(admin.canEditTitle)
        XCTAssertFalse(admin.canEditEditor)
        XCTAssertFalse(admin.canEditCategory)
        XCTAssertFalse(admin.canEditAirDate)
    }

    func testPhase6Fix01LinkedModuleModeResolverUsesEligibility() {
        let current = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let otherProfile = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let waitingCurrent = videoTask(id: "00000000-0000-0000-0000-0000000006a1", contentPlanID: "90000000-0000-0000-0000-0000000006a1", editorProfileID: current, status: .waiting)
        let waitingOther = videoTask(id: "00000000-0000-0000-0000-0000000006a2", contentPlanID: "90000000-0000-0000-0000-0000000006a2", editorProfileID: otherProfile, status: .waiting)
        let doingCurrent = videoTask(id: "00000000-0000-0000-0000-0000000006a3", contentPlanID: "90000000-0000-0000-0000-0000000006a3", editorProfileID: current, status: .inProgress)
        let doingOther = videoTask(id: "00000000-0000-0000-0000-0000000006a4", contentPlanID: "90000000-0000-0000-0000-0000000006a4", editorProfileID: otherProfile, status: .inProgress)
        let update = VideoTaskPermissions(canCreate: false, canUpdate: true, canDelete: false, isAdmin: false, currentProfileID: current)
        let admin = VideoTaskPermissions(canCreate: true, canUpdate: true, canDelete: true, isAdmin: true, currentProfileID: current)

        XCTAssertEqual(VideoTaskModuleMode.resolve(task: waitingCurrent, permissions: update), .linkedAccept(waitingCurrent))
        XCTAssertEqual(VideoTaskModuleMode.resolve(task: waitingCurrent, permissions: update).title, "Nhận Task")
        XCTAssertEqual(VideoTaskModuleMode.resolve(task: waitingOther, permissions: update), .linkedPassiveDetail(waitingOther))
        XCTAssertEqual(VideoTaskModuleMode.resolve(task: waitingOther, permissions: update).title, "Chi tiết Task")
        XCTAssertEqual(VideoTaskModuleMode.resolve(task: doingCurrent, permissions: update), .linkedExecution(doingCurrent))
        XCTAssertEqual(VideoTaskModuleMode.resolve(task: doingCurrent, permissions: update).title, "Hoàn thành Task")
        XCTAssertEqual(VideoTaskModuleMode.resolve(task: doingOther, permissions: update), .linkedPassiveDetail(doingOther))
        XCTAssertEqual(VideoTaskModuleMode.resolve(task: waitingOther, permissions: admin), .linkedAdminOverride(waitingOther))
    }

    func testPhase6Fix01DeleteConfirmationDoesNotMutateWorkflowMode() async {
        let current = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let waiting = videoTask(id: "00000000-0000-0000-0000-0000000006b1", contentPlanID: "90000000-0000-0000-0000-0000000006b1", editorProfileID: current, returnDate: "2026-08-20", status: .waiting)
        let doing = videoTask(id: "00000000-0000-0000-0000-0000000006b2", contentPlanID: "90000000-0000-0000-0000-0000000006b2", editorProfileID: current, receiveDate: "2026-08-01", returnDate: "2026-08-04", status: .inProgress)
        let provider = TestVideoTaskProvider(tasks: [waiting, doing])
        let permissions = VideoTaskPermissions(canCreate: false, canUpdate: true, canDelete: true, isAdmin: false, currentProfileID: current)
        let viewModel = VideoTaskViewModel(provider: provider, monthValue: "2026-08", timeScope: .month, nowProvider: { VideoTaskDateFormatter.date(from: "2026-08-18")! })
        await viewModel.load()

        viewModel.open(task: waiting, permissions: permissions)
        let acceptMode = viewModel.moduleMode
        let acceptForm = viewModel.formData
        let acceptDates = viewModel.acceptData
        XCTAssertEqual(acceptMode, .linkedAccept(waiting))
        viewModel.requestDelete()
        XCTAssertEqual(viewModel.moduleMode, acceptMode)
        XCTAssertEqual(viewModel.formData, acceptForm)
        XCTAssertEqual(viewModel.acceptData, acceptDates)
        XCTAssertTrue(viewModel.fieldState(permissions: permissions).canAccept)
        viewModel.cancelDelete()
        XCTAssertEqual(viewModel.moduleMode, acceptMode)
        XCTAssertTrue(viewModel.fieldState(permissions: permissions).canAccept)

        viewModel.open(task: doing, permissions: permissions)
        viewModel.formData.resultLink = "https://example.com/final"
        let executionMode = viewModel.moduleMode
        let executionForm = viewModel.formData
        XCTAssertEqual(executionMode, .linkedExecution(doing))
        viewModel.requestDelete()
        XCTAssertEqual(viewModel.moduleMode, executionMode)
        XCTAssertEqual(viewModel.formData, executionForm)
        viewModel.cancelDelete()
        XCTAssertEqual(viewModel.moduleMode, executionMode)
        XCTAssertTrue(viewModel.fieldState(permissions: permissions).canComplete)
    }

    func testPhase6Fix01FilterResetSecondarySemanticsAndMonthNavigation() async {
        let provider = TestVideoTaskProvider(tasks: [
            videoTask(id: "00000000-0000-0000-0000-0000000006c1", title: "Motion A", editorCode: "dat", orderTeam: "BRAND", category: .motion, airDate: "2026-08-01", status: .done, note: "Alpha"),
            videoTask(id: "00000000-0000-0000-0000-0000000006c2", title: "Ads B", editorCode: "hai", orderTeam: "DIGITAL", category: .ads, airDate: "2026-08-02", status: .waiting, note: "Beta")
        ])
        let viewModel = VideoTaskViewModel(provider: provider, monthValue: "2026-08", timeScope: .month)
        await viewModel.load()

        viewModel.editorFilter = "hai"
        viewModel.orderFilter = "DIGITAL"
        viewModel.categoryFilter = "Ads"
        XCTAssertEqual(viewModel.visibleTasks.map(\.title), ["Ads B"])
        viewModel.search = "Beta"
        viewModel.statusFilter = .waiting
        XCTAssertEqual(viewModel.visibleTasks.map(\.title), ["Ads B"])
        viewModel.resetFilters()
        XCTAssertEqual(viewModel.search, "")
        XCTAssertEqual(viewModel.statusFilter, .all)
        XCTAssertEqual(viewModel.editorFilter, "all")
        XCTAssertEqual(viewModel.orderFilter, "all")
        XCTAssertEqual(viewModel.categoryFilter, "all")

        await viewModel.shiftMonth(-1)
        XCTAssertEqual(viewModel.monthValue, "2026-07")
        await viewModel.shiftMonth(1)
        XCTAssertEqual(viewModel.monthValue, "2026-08")
    }

    func testPhase6RPCContractsForLinkedWorkflowsAndDelete() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000650")!
        XCTAssertEqual(try VideoTaskRPCContract.acceptParams(id: id, data: VideoTaskAcceptData(receiveDate: "2026-08-01", returnDate: "2026-08-02")), [
            "p_video_task_id": id.uuidString,
            "p_receive_date": "2026-08-01",
            "p_return_date": "2026-08-02"
        ])
        let execution = try VideoTaskRPCContract.executionParams(id: id, data: VideoTaskExecutionData(
            orderTeam: "DIGITAL",
            priority: .urgent,
            resize: "9x16",
            receiveDate: "2026-08-03",
            returnDate: "2026-08-05",
            resultLink: "https://example.com/result"
        ))
        XCTAssertEqual(execution["p_order_team"], "DIGITAL")
        XCTAssertEqual(execution["p_priority"], "Gấp")
        XCTAssertEqual(execution["p_result_link"], "https://example.com/result")
        XCTAssertEqual(try VideoTaskRPCContract.completeParams(id: id, resultLink: "https://example.com/done")["p_result_link"], "https://example.com/done")
        XCTAssertEqual(VideoTaskRPCContract.deleteParams(id: id), ["p_video_task_id": id.uuidString])
        XCTAssertThrowsError(try VideoTaskRPCContract.completeParams(id: id, resultLink: "notaurl")) { error in
            XCTAssertEqual((error as? VideoTaskValidationError), .invalidResultLink)
        }
    }

    func testPhase6FixtureCoversStandaloneLinkedUrgentCategoriesAndSafeLinks() async throws {
        let provider = VideoTaskFixtureProvider(mode: .full)
        let tasks = try await provider.fetchTasks(monthValue: "2026-08")

        XCTAssertFalse(provider.usesProductionData)
        XCTAssertTrue(tasks.contains { !$0.isLinked && $0.status == .waiting })
        XCTAssertTrue(tasks.contains { !$0.isLinked && $0.status == .inProgress })
        XCTAssertTrue(tasks.contains { !$0.isLinked && $0.status == .done })
        XCTAssertTrue(tasks.contains { $0.priority == .urgent })
        XCTAssertEqual(Set(tasks.map(\.category)), Set(VideoTaskCategory.allCases))
        XCTAssertTrue(tasks.contains { $0.isLinked && $0.status == .waiting && $0.editorCode == "dat" })
        XCTAssertTrue(tasks.contains { $0.isLinked && $0.status == .inProgress && $0.editorCode == "dat" })
        XCTAssertTrue(tasks.contains { $0.isLinked && $0.status == .done })
        XCTAssertTrue(tasks.contains { $0.isResultLinkActionable })
        XCTAssertTrue(tasks.contains { $0.resultLink.isEmpty })
    }

    func testPhase6ViewModelFiltersSearchMonthAndEmptySemantics() async {
        let provider = TestVideoTaskProvider(tasks: [
            videoTask(id: "00000000-0000-0000-0000-000000000661", title: "Motion A", editorCode: "dat", orderTeam: "BRAND", category: .motion, airDate: "2026-08-01", status: .done, priority: .normal, note: "Alpha"),
            videoTask(id: "00000000-0000-0000-0000-000000000662", title: "Ads B", editorCode: "hai", orderTeam: "DIGITAL", category: .ads, airDate: "2026-08-02", status: .waiting, priority: .urgent, note: "Beta")
        ])
        let viewModel = VideoTaskViewModel(provider: provider, monthValue: "2026-08", timeScope: .month)
        await viewModel.load()

        XCTAssertEqual(viewModel.visibleTasks.count, 2)
        viewModel.search = "alpha"
        XCTAssertEqual(viewModel.visibleTasks.map(\.title), ["Motion A"])
        viewModel.search = ""
        viewModel.statusFilter = .waiting
        XCTAssertEqual(viewModel.visibleTasks.map(\.title), ["Ads B"])
        viewModel.editorFilter = "dat"
        XCTAssertTrue(viewModel.visibleTasks.isEmpty)
        XCTAssertTrue(viewModel.hasActiveFilters)
        viewModel.resetFilters()
        viewModel.categoryFilter = "Motion"
        XCTAssertEqual(viewModel.visibleTasks.map(\.category), [.motion])
    }

    func testPhase6ViewModelStandaloneMutationsReloadAndPreserveModuleOnFailure() async {
        let provider = TestVideoTaskProvider(tasks: [videoTask(id: "00000000-0000-0000-0000-000000000671")])
        let viewModel = VideoTaskViewModel(provider: provider, monthValue: "2026-08", timeScope: .month)
        let permissions = VideoTaskPermissions(canCreate: true, canUpdate: true, canDelete: true, isAdmin: false, currentProfileID: nil)
        await viewModel.load()

        viewModel.openCreate()
        viewModel.formData.title = "Created"
        viewModel.formData.airDate = "2026-08-09"
        let didCreate = await viewModel.save(permissions: permissions)
        XCTAssertTrue(didCreate)
        XCTAssertEqual(provider.createCount, 1)
        XCTAssertEqual(provider.fetchCount, 2)

        provider.mutationResult = .failure(VideoTaskRepositoryError.backend("Không thể lưu task."))
        viewModel.open(task: viewModel.tasks[0], permissions: permissions)
        let didSaveFailure = await viewModel.save(permissions: permissions)
        XCTAssertFalse(didSaveFailure)
        XCTAssertNotNil(viewModel.moduleMode)
        XCTAssertEqual(viewModel.modalError, "Không thể lưu task.")
    }

    func testPhase6LinkedWorkflowMutationsUseDedicatedProviderPaths() async {
        let current = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let waiting = videoTask(id: "00000000-0000-0000-0000-000000000681", contentPlanID: "90000000-0000-0000-0000-000000000681", editorProfileID: current, status: .waiting)
        let doing = videoTask(id: "00000000-0000-0000-0000-000000000682", contentPlanID: "90000000-0000-0000-0000-000000000682", editorProfileID: current, receiveDate: "2026-08-01", returnDate: "2026-08-02", status: .inProgress)
        let provider = TestVideoTaskProvider(tasks: [waiting, doing])
        let permissions = VideoTaskPermissions(canCreate: true, canUpdate: true, canDelete: true, isAdmin: false, currentProfileID: current)
        let viewModel = VideoTaskViewModel(provider: provider, monthValue: "2026-08", timeScope: .month, nowProvider: { VideoTaskDateFormatter.date(from: "2026-08-18")! })
        await viewModel.load()

        viewModel.open(task: waiting, permissions: permissions)
        viewModel.acceptData.returnDate = "2026-08-20"
        let didAccept = await viewModel.accept(permissions: permissions)
        XCTAssertTrue(didAccept)
        XCTAssertEqual(provider.acceptCount, 1)

        viewModel.open(task: doing, permissions: permissions)
        viewModel.formData.resultLink = "https://example.com/final"
        let didSaveExecution = await viewModel.saveExecution(permissions: permissions)
        let didComplete = await viewModel.complete(permissions: permissions)
        XCTAssertTrue(didSaveExecution)
        XCTAssertTrue(didComplete)
        XCTAssertEqual(provider.executionCount, 2)
        XCTAssertEqual(provider.completeCount, 1)
    }

    func testPhase6DeleteSemanticsAndProductionProviderDefault() async {
        let linked = videoTask(id: "00000000-0000-0000-0000-000000000691", contentPlanID: "90000000-0000-0000-0000-000000000691")
        let provider = TestVideoTaskProvider(tasks: [linked])
        let permissions = VideoTaskPermissions(canCreate: false, canUpdate: true, canDelete: true, isAdmin: false, currentProfileID: nil)
        let viewModel = VideoTaskViewModel(provider: provider, monthValue: "2026-08", timeScope: .month)

        await viewModel.load()
        viewModel.open(task: linked, permissions: permissions)
        viewModel.requestDelete()
        let didDelete = await viewModel.confirmDelete(permissions: permissions)
        XCTAssertTrue(didDelete)
        XCTAssertEqual(provider.deleteCount, 1)
        XCTAssertEqual(provider.deletedLinkedTaskContentPlanID, linked.contentPlanID)
        XCTAssertTrue(VideoTaskProviderFactory.makeProvider().usesProductionData)
    }

    func testPhase6ModuleRouterAndCurrentProfileIdentity() async {
        let fake = FakeAuthService()
        fake.restoredSessionResult = .success(.sample)
        fake.bootstrapResult = .success(.sample)
        let state = AppState(authService: fake)
        await state.start()
        XCTAssertEqual(state.currentProfileID, AuthenticatedUser.sample.id)

        let router = AppRouter()
        router.selectMain(.video)
        router.pushModule(.taskCreate)
        XCTAssertFalse(router.isBottomNavigationVisible)
        router.pop()
        XCTAssertEqual(router.selectedMain, .video)
        XCTAssertTrue(router.isBottomNavigationVisible)
    }

    func testPhase7ContentPlanDataContractValidationAndRPCParams() throws {
        XCTAssertEqual(ContentPlanCategory.allCases.map(\.rawValue), ["Video dài", "Short/Reels", "Livestream", "Ảnh", "Motion", "Ads"])
        XCTAssertTrue(ContentPlanCategory.longForm.canCreateVideoTask)
        XCTAssertFalse(ContentPlanCategory.image.canCreateVideoTask)

        let valid = ContentPlanFormData(airDate: "2026-08-01", title: "  Video mới  ", note: "Ghi chú", category: .motion, editorCode: "", link: "https://example.com/result")
        let payload = try ContentPlanPayload(data: valid, includeEditor: false)
        XCTAssertEqual(payload.airDate, "2026-08-01")
        XCTAssertEqual(payload.title, "Video mới")
        XCTAssertEqual(payload.category, "Motion")
        XCTAssertEqual(payload.link, "https://example.com/result")

        XCTAssertThrowsError(try ContentPlanPayload(data: ContentPlanFormData(airDate: "2026-08-40", title: "Video", note: "", category: .longForm, editorCode: "", link: ""), includeEditor: false))
        XCTAssertThrowsError(try ContentPlanPayload(data: ContentPlanFormData(airDate: "2026-08-01", title: "", note: "", category: .longForm, editorCode: "", link: ""), includeEditor: false))
        XCTAssertThrowsError(try ContentPlanPayload(data: ContentPlanFormData(airDate: "2026-08-01", title: "Video", note: "", category: .longForm, editorCode: "", link: "javascript:alert(1)"), includeEditor: false))

        let params = try ContentPlanRPCContract.createParams(data: valid)
        XCTAssertEqual(params["p_air_date"], "2026-08-01")
        XCTAssertEqual(params["p_title"], "Video mới")
        XCTAssertEqual(params["p_category"], "Motion")
        XCTAssertEqual(ContentPlanRPCContract.deleteParams(id: UUID(uuidString: "00000000-0000-0000-0000-000000000701")!)["p_content_plan_id"], "00000000-0000-0000-0000-000000000701")
    }

    func testPhase7ContentPlanPermissionsAndModuleModes() {
        let item = contentPlanItem(id: "00000000-0000-0000-0000-000000000711", linkedTaskID: "00000000-0000-0000-0000-000000000611", linkedTaskStatus: "Chờ")
        let started = contentPlanItem(id: "00000000-0000-0000-0000-000000000712", linkedTaskID: "00000000-0000-0000-0000-000000000612", linkedTaskStatus: "Đang làm")
        let readOnly = ContentPlanPermissions(canCreate: false, canUpdate: false, canAssign: false, canDelete: false, isAdmin: false, currentProfileID: nil)
        let assign = ContentPlanPermissions(canCreate: false, canUpdate: false, canAssign: true, canDelete: false, isAdmin: false, currentProfileID: nil)
        let edit = ContentPlanPermissions(canCreate: true, canUpdate: true, canAssign: true, canDelete: true, isAdmin: false, currentProfileID: nil)

        XCTAssertEqual(ContentPlanModuleMode.resolve(item: item, permissions: readOnly), .readOnly(item))
        XCTAssertEqual(ContentPlanModuleMode.resolve(item: item, permissions: assign), .assign(item))
        XCTAssertEqual(ContentPlanModuleMode.resolve(item: item, permissions: edit), .edit(item))

        let readOnlyState = ContentPlanFieldState.resolve(mode: .readOnly(item), permissions: readOnly)
        XCTAssertFalse(readOnlyState.canSave)
        XCTAssertFalse(readOnlyState.canEditEditor)

        let linkedEditState = ContentPlanFieldState.resolve(mode: .edit(item), permissions: edit)
        XCTAssertTrue(linkedEditState.canEditTitle)
        XCTAssertTrue(linkedEditState.canEditEditor)
        XCTAssertFalse(linkedEditState.canEditLink)

        let startedEditState = ContentPlanFieldState.resolve(mode: .edit(started), permissions: edit)
        XCTAssertTrue(startedEditState.canEditTitle)
        XCTAssertFalse(startedEditState.canEditEditor)
        XCTAssertFalse(startedEditState.canEditLink)
    }

    func testPhase7Fix01ContentPlanTaskStateSemanticsAndLoadErrorCopy() {
        let incompatible = contentPlanItem(id: "00000000-0000-0000-0000-000000000713", category: .image, editorCode: "")
        XCTAssertEqual(incompatible.taskStateLabel, "Không tạo Video Task")

        let impossible = contentPlanItem(id: "00000000-0000-0000-0000-000000000714", category: .motion, editorCode: "dat")
        XCTAssertTrue(impossible.hasInconsistentMissingLinkedTask)
        XCTAssertEqual(impossible.taskStateLabel, "Cần đồng bộ Task")

        let linked = contentPlanItem(id: "00000000-0000-0000-0000-000000000715", category: .ads, linkedTaskID: "00000000-0000-0000-0000-000000000615", linkedTaskStatus: "Đã xong")
        XCTAssertEqual(linked.taskStateLabel, "Task · Đã xong")

        let safeLoadMessage = ContentPlanViewModel.loadMessage(for: ContentPlanRepositoryError.backend("Fixture SQL RPC backend failure"))
        XCTAssertEqual(safeLoadMessage, "Không thể tải dữ liệu Content Plan. Vui lòng thử lại.")
        XCTAssertFalse(safeLoadMessage.localizedCaseInsensitiveContains("Fixture"))
        XCTAssertFalse(safeLoadMessage.localizedCaseInsensitiveContains("SQL"))
    }

    func testPhase7ContentPlanViewModelFiltersSortAndReset() async {
        let linked = contentPlanItem(id: "00000000-0000-0000-0000-000000000721", airDate: "2026-08-02", title: "Linked", category: .motion, editorCode: "minh", linkedTaskID: "00000000-0000-0000-0000-000000000621")
        let done = contentPlanItem(id: "00000000-0000-0000-0000-000000000722", airDate: "2026-08-01", title: "Done", category: .longForm, editorCode: "dat", link: "https://example.com/done")
        let todo = contentPlanItem(id: "00000000-0000-0000-0000-000000000723", airDate: "2026-08-01", title: "Todo", category: .ads, editorCode: "hai")
        let provider = TestContentPlanProvider(items: [done, linked, todo])
        let viewModel = ContentPlanViewModel(provider: provider, monthValue: "2026-08", timeScope: .month)

        await viewModel.load()
        XCTAssertEqual(viewModel.visibleItems.map(\.title), ["Todo", "Linked", "Done"])

        viewModel.editorFilter = "minh"
        XCTAssertEqual(viewModel.visibleItems.map(\.title), ["Linked"])
        viewModel.categoryFilter = .motion
        viewModel.search = "link"
        XCTAssertEqual(viewModel.visibleItems.count, 1)
        XCTAssertTrue(viewModel.hasActiveFilters)
        viewModel.resetFilters()
        XCTAssertFalse(viewModel.hasActiveFilters)
        XCTAssertEqual(viewModel.visibleItems.count, 3)
    }

    func testPhase7ContentPlanCreateUpdateAssignDeletePaths() async {
        let item = contentPlanItem(id: "00000000-0000-0000-0000-000000000731", editorCode: "")
        let provider = TestContentPlanProvider(items: [item])
        let permissions = ContentPlanPermissions(canCreate: true, canUpdate: true, canAssign: true, canDelete: true, isAdmin: false, currentProfileID: AuthenticatedUser.sample.id)
        let viewModel = ContentPlanViewModel(provider: provider, monthValue: "2026-08", timeScope: .month)
        await viewModel.load()

        viewModel.openCreate()
        viewModel.formData.title = "New Plan"
        let didCreate = await viewModel.save(permissions: permissions)
        XCTAssertTrue(didCreate)
        XCTAssertEqual(provider.createCount, 1)

        viewModel.open(item: item, permissions: permissions)
        viewModel.formData.title = "Updated Plan"
        let didUpdate = await viewModel.save(permissions: permissions)
        XCTAssertTrue(didUpdate)
        XCTAssertEqual(provider.updateCount, 1)

        viewModel.open(item: item, permissions: permissions)
        viewModel.formData.editorCode = "dat"
        let didAssign = await viewModel.save(permissions: permissions)
        XCTAssertTrue(didAssign)
        XCTAssertEqual(provider.assignCount, 1)

        viewModel.open(item: item, permissions: permissions)
        viewModel.formData.title = "Mixed"
        viewModel.formData.editorCode = "hai"
        let didRejectMixedSave = await viewModel.save(permissions: permissions)
        XCTAssertFalse(didRejectMixedSave)
        XCTAssertEqual(viewModel.modalError, ContentPlanValidationError.mixedContentAndAssignment.errorDescription)

        viewModel.requestDelete()
        let didDelete = await viewModel.confirmDelete(permissions: permissions)
        XCTAssertTrue(didDelete)
        XCTAssertEqual(provider.deleteCount, 1)
    }

    func testPhase7Fix01FixtureMatchesAssignmentContract() async throws {
        let provider = ContentPlanFixtureProvider(mode: .full)
        let initial = try await provider.fetchItems(monthValue: "2026-08")
        XCTAssertFalse(initial.contains(where: \.hasInconsistentMissingLinkedTask))
        XCTAssertTrue(initial.filter { !$0.category.canCreateVideoTask }.allSatisfy { $0.taskStateLabel == "Không tạo Video Task" })

        let unassigned = try XCTUnwrap(initial.first { $0.id.uuidString == "00000000-0000-0000-0000-000000000701" })
        let result = try await provider.assignEditor(id: unassigned.id, editorCode: "dat")
        XCTAssertEqual(result.taskStatus, "Chờ")
        XCTAssertNotNil(result.videoTaskID)

        let afterAssign = try await provider.fetchItems(monthValue: "2026-08")
        let assigned = try XCTUnwrap(afterAssign.first { $0.id == unassigned.id })
        XCTAssertTrue(assigned.hasLinkedTask)
        XCTAssertEqual(assigned.linkedTaskStatus, "Chờ")
        XCTAssertFalse(assigned.hasInconsistentMissingLinkedTask)

        let image = try XCTUnwrap(initial.first { $0.category == .image })
        do {
            _ = try await provider.assignEditor(id: image.id, editorCode: "dat")
            XCTFail("Incompatible category must not create a Video Task")
        } catch {
            XCTAssertEqual(ContentPlanViewModel.message(for: error), "Thể loại Content Plan chưa tương thích với Video tháng.")
        }
    }

    func testPhase7ContentPlanDeleteConfirmationDoesNotMutateModuleMode() async {
        let item = contentPlanItem(id: "00000000-0000-0000-0000-000000000741", linkedTaskID: "00000000-0000-0000-0000-000000000641")
        let provider = TestContentPlanProvider(items: [item])
        let permissions = ContentPlanPermissions(canCreate: false, canUpdate: true, canAssign: true, canDelete: true, isAdmin: false, currentProfileID: nil)
        let viewModel = ContentPlanViewModel(provider: provider, monthValue: "2026-08", timeScope: .month)
        await viewModel.load()
        viewModel.open(item: item, permissions: permissions)
        XCTAssertEqual(viewModel.moduleMode, .edit(item))
        viewModel.formData.note = "Draft note"
        viewModel.requestDelete()
        XCTAssertEqual(viewModel.moduleMode, .edit(item))
        XCTAssertEqual(viewModel.formData.note, "Draft note")
        viewModel.cancelDelete()
        XCTAssertEqual(viewModel.moduleMode, .edit(item))
        XCTAssertEqual(viewModel.formData.note, "Draft note")
    }

    func testPhase11SharedTimeScopeUsesCanonicalDateContracts() async {
        let selected = VideoTaskDateFormatter.date(from: "2026-08-18")!
        let videoProvider = TestVideoTaskProvider(tasks: [
            videoTask(id: "00000000-0000-0000-0000-000000001101", title: "Canonical air", receiveDate: "2026-08-01", returnDate: "2026-09-01", airDate: "2026-08-18"),
            videoTask(id: "00000000-0000-0000-0000-000000001102", title: "Receive date only", receiveDate: "2026-08-18", returnDate: "2026-08-19", airDate: "2026-08-25")
        ])
        let video = VideoTaskViewModel(provider: videoProvider, monthValue: "2026-08", timeScope: .week, selectedDate: selected, nowProvider: { selected })
        await video.load()
        XCTAssertEqual(video.visibleTasks.map(\.title), ["Canonical air"])

        let selectedVideoDay = video.weekDays.first { $0.isoDate == "2026-08-18" }!
        await video.selectDay(selectedVideoDay)
        XCTAssertEqual(video.timeScope, .day)
        XCTAssertEqual(video.visibleTasks.map(\.title), ["Canonical air"])

        await video.selectScope(.month)
        XCTAssertEqual(video.visibleTasks.map(\.title), ["Canonical air", "Receive date only"])

        let calendarProvider = TestCalendarProvider(
            shoots: [
                calendarShoot(id: "00000000-0000-0000-0000-000000001111", date: "2026-08-18", content: "Shoot canonical"),
                calendarShoot(id: "00000000-0000-0000-0000-000000001112", date: "2026-08-25", content: "Shoot next week")
            ],
            editors: []
        )
        let calendar = CalendarViewModel(provider: calendarProvider, initialDate: selected, timeScope: .week, nowProvider: { selected })
        await calendar.load()
        XCTAssertEqual(calendar.visibleShoots.map(\.content), ["Shoot canonical"])

        let selectedCalendarDay = calendar.weekDays.first { $0.isoDate == "2026-08-18" }!
        await calendar.selectDay(selectedCalendarDay)
        XCTAssertEqual(calendar.visibleShoots.map(\.content), ["Shoot canonical"])

        await calendar.selectScope(.month)
        XCTAssertEqual(calendar.visibleShoots.map(\.content), ["Shoot canonical", "Shoot next week"])

        let contentProvider = TestContentPlanProvider(items: [
            contentPlanItem(id: "00000000-0000-0000-0000-000000001121", airDate: "2026-08-18", title: "Air canonical"),
            contentPlanItem(id: "00000000-0000-0000-0000-000000001122", airDate: "2026-08-25", title: "Air next week")
        ])
        let content = ContentPlanViewModel(provider: contentProvider, monthValue: "2026-08", timeScope: .week, selectedDate: selected)
        await content.load()
        XCTAssertEqual(content.visibleItems.map(\.title), ["Air canonical"])

        let selectedContentDay = content.weekDays.first { $0.isoDate == "2026-08-18" }!
        await content.selectDay(selectedContentDay)
        XCTAssertEqual(content.visibleItems.map(\.title), ["Air canonical"])

        await content.selectScope(.month)
        XCTAssertEqual(content.visibleItems.map(\.title), ["Air canonical", "Air next week"])
    }

    func testPhase11WeekBoundariesCrossMonthAndYearWithoutBroadeningRange() async {
        let august31 = VideoTaskDateFormatter.date(from: "2026-08-31")!
        let videoProvider = TestVideoTaskProvider(tasks: [
            videoTask(id: "00000000-0000-0000-0000-000000001131", title: "Week starts August", airDate: "2026-08-31"),
            videoTask(id: "00000000-0000-0000-0000-000000001132", title: "Week enters September", airDate: "2026-09-01"),
            videoTask(id: "00000000-0000-0000-0000-000000001133", title: "Outside selected week", airDate: "2026-09-07")
        ])
        let video = VideoTaskViewModel(provider: videoProvider, monthValue: "2026-08", timeScope: .week, selectedDate: august31, nowProvider: { august31 })
        await video.load()

        XCTAssertEqual(video.selectedRange.start, "2026-08-31")
        XCTAssertEqual(video.selectedRange.end, "2026-09-06")
        XCTAssertEqual(videoProvider.fetchedMonthValues, ["2026-08", "2026-09"])
        XCTAssertEqual(video.visibleTasks.map(\.title), ["Week starts August", "Week enters September"])

        let yearBoundary = CHTimeNavigation.range(for: .week, selectedDate: VideoTaskDateFormatter.date(from: "2026-12-31")!, monthValue: "2026-12")
        XCTAssertEqual(yearBoundary.start, "2026-12-28")
        XCTAssertEqual(yearBoundary.end, "2027-01-03")
        XCTAssertEqual(CHTimeNavigation.monthValuesTouching(range: yearBoundary), ["2026-12", "2027-01"])
    }

    func testPhase11Fix03WeekNavigationSelectsMondayAfterManualNextPrevious() async {
        let friday = VideoTaskDateFormatter.date(from: "2026-08-21")!

        let video = VideoTaskViewModel(
            provider: TestVideoTaskProvider(tasks: []),
            monthValue: "2026-08",
            timeScope: .week,
            selectedDate: friday,
            nowProvider: { friday }
        )
        await video.shiftWeek(1)
        XCTAssertEqual(CHTimeNavigation.isoString(from: video.selectedDate), "2026-08-24")
        await video.shiftWeek(-1)
        XCTAssertEqual(CHTimeNavigation.isoString(from: video.selectedDate), "2026-08-17")

        let calendar = CalendarViewModel(
            provider: TestCalendarProvider(shoots: [], editors: []),
            initialDate: friday,
            timeScope: .week,
            nowProvider: { friday }
        )
        await calendar.shiftWeek(1)
        XCTAssertEqual(CHTimeNavigation.isoString(from: calendar.selectedDate), "2026-08-24")
        await calendar.shiftWeek(-1)
        XCTAssertEqual(CHTimeNavigation.isoString(from: calendar.selectedDate), "2026-08-17")

        let content = ContentPlanViewModel(
            provider: TestContentPlanProvider(items: []),
            monthValue: "2026-08",
            timeScope: .week,
            selectedDate: friday,
            nowProvider: { friday }
        )
        await content.shiftWeek(1)
        XCTAssertEqual(CHTimeNavigation.isoString(from: content.selectedDate), "2026-08-24")
        await content.shiftWeek(-1)
        XCTAssertEqual(CHTimeNavigation.isoString(from: content.selectedDate), "2026-08-17")
    }

    func testPhase11Fix03CurrentWeekInitialStateKeepsTodaySelected() async {
        let friday = VideoTaskDateFormatter.date(from: "2026-08-21")!
        let userID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let viewModel = VideoTaskViewModel(
            provider: TestVideoTaskProvider(tasks: []),
            monthValue: "2026-01",
            timeScope: .month,
            selectedDate: VideoTaskDateFormatter.date(from: "2026-01-01")!,
            nowProvider: { friday },
            preferenceStore: InMemoryTimeScopePreferenceStore()
        )

        await viewModel.configurePreferenceProfile(userID)

        XCTAssertEqual(viewModel.timeScope, .week)
        XCTAssertEqual(CHTimeNavigation.isoString(from: viewModel.selectedDate), "2026-08-21")
    }

    func testPhase11Fix03CalendarRefreshFailureRetainsExistingDataAndSelection() async {
        let selected = CalendarDateFormatter.date(from: "2026-08-21")!
        let existing = calendarShoot(id: "00000000-0000-0000-0000-000000001161", date: "2026-08-21", content: "Existing shoot")
        let provider = TestCalendarProvider(
            shoots: [existing],
            editors: [],
            loadResults: [.success, .failure(CalendarRepositoryError.backend("supabase raw error"))]
        )
        let viewModel = CalendarViewModel(provider: provider, initialDate: selected, timeScope: .week, nowProvider: { selected })

        await viewModel.load()
        viewModel.filter = .onset
        let message = await viewModel.refresh()

        XCTAssertNotNil(message)
        XCTAssertEqual(viewModel.shoots.map(\.content), ["Existing shoot"])
        XCTAssertEqual(CHTimeNavigation.isoString(from: viewModel.selectedDate), "2026-08-21")
        XCTAssertEqual(viewModel.timeScope, .week)
        XCTAssertEqual(viewModel.filter, .onset)
        XCTAssertEqual(viewModel.loadState, .loaded)
    }

    func testPhase11Fix04CancellationRefreshIsSilentAndRetainsCalendarState() async {
        let selected = CalendarDateFormatter.date(from: "2026-08-21")!
        let existing = calendarShoot(id: "00000000-0000-0000-0000-000000001162", date: "2026-08-21", content: "Retained shoot")
        let provider = TestCalendarProvider(
            shoots: [existing],
            editors: [],
            loadResults: [.success, .failure(CancellationError())]
        )
        let viewModel = CalendarViewModel(provider: provider, initialDate: selected, timeScope: .week, nowProvider: { selected })

        await viewModel.load()
        viewModel.filter = .onset
        let message = await viewModel.refresh()

        XCTAssertNil(message)
        XCTAssertEqual(viewModel.shoots.map(\.content), ["Retained shoot"])
        XCTAssertEqual(viewModel.filter, .onset)
        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertTrue(AsyncCancellation.isCancellation(CancellationError()))
        XCTAssertTrue(AsyncCancellation.isCancellation(URLError(.cancelled)))
        XCTAssertFalse(VideoTaskViewModel.message(for: CancellationError()).contains("Swift.CancellationError"))
    }

    func testPhase11Fix03NotificationRefreshUpdatesUnreadState() async {
        let provider = TestNotificationProvider(
            notifications: NotificationFixtureRepository.seedNotifications,
            markReadResult: .success(NotificationFixtureRepository.baseDate)
        )
        let viewModel = NotificationViewModel(provider: provider, limit: 20)

        await viewModel.load()
        let initialUnread = viewModel.unreadCount
        _ = await viewModel.markAllRead()
        let message = await viewModel.refresh()

        XCTAssertNil(message)
        XCTAssertGreaterThan(initialUnread, 0)
        XCTAssertEqual(viewModel.unreadCount, 0)
    }

    func testFinalHardeningNotificationUnreadRefreshCancellationIsSilent() async {
        let provider = TestNotificationProvider(
            notifications: NotificationFixtureRepository.seedNotifications,
            markReadResult: .success(NotificationFixtureRepository.baseDate)
        )
        let viewModel = NotificationViewModel(provider: provider, limit: 20)

        await viewModel.load()
        let initialUnread = viewModel.unreadCount
        await provider.setUnreadCountError(CancellationError())
        await viewModel.refreshUnreadIndicator()

        XCTAssertEqual(viewModel.unreadCount, initialUnread)
        if case .failed = viewModel.loadState {
            XCTFail("Cancellation should not move notifications into a failed state.")
        }
    }

    func testFinalHardeningNotificationForegroundRefreshLoopStopsOnLogoutAndBackground() async {
        let loop = InAppNotificationRefreshLoop(intervalNanoseconds: 10_000_000)
        let initialTick = loop.tick

        loop.reconcile(isAuthenticated: true, isSceneActive: true)
        XCTAssertTrue(loop.isRunning)
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertNotEqual(loop.tick, initialTick)

        loop.reconcile(isAuthenticated: true, isSceneActive: false)
        let backgroundTick = loop.tick
        XCTAssertFalse(loop.isRunning)
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(loop.tick, backgroundTick)

        loop.reconcile(isAuthenticated: true, isSceneActive: true)
        XCTAssertTrue(loop.isRunning)
        loop.reconcile(isAuthenticated: false, isSceneActive: true)
        XCTAssertFalse(loop.isRunning)
    }

    func testFinalStabilizationRemotePushDeferredButInAppRoutesRemainAvailable() {
        let taskID = UUID(uuidString: "00000000-0000-0000-0000-000000001171")!

        XCTAssertFalse(RemotePushNotificationStatus.isEnabled)
        XCTAssertEqual(
            NotificationActionResolver.destination(from: "/tasks?highlight=\(taskID.uuidString)"),
            .videoTask(taskID)
        )
    }

    func testFinalStabilizationNotificationActionResolverDestinations() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000001172")!

        XCTAssertEqual(
            NotificationActionResolver.destination(from: "/tasks?highlight=\(id.uuidString)"),
            .videoTask(id)
        )
        XCTAssertEqual(
            NotificationActionResolver.destination(from: "/calendar?highlight=\(id.uuidString)"),
            .calendarShoot(id)
        )
        XCTAssertEqual(
            NotificationActionResolver.destination(from: "/content-plan?highlight=\(id.uuidString)"),
            .contentPlan(id)
        )
        XCTAssertEqual(
            NotificationActionResolver.destination(from: "/users"),
            .members
        )
        XCTAssertNil(NotificationActionResolver.destination(from: nil))
        XCTAssertNil(NotificationActionResolver.destination(from: "https://example.com/tasks?highlight=\(id.uuidString)"))
    }

    func testPhase11Fix01TimeScopePreferencesAreUserAndModuleScoped() async {
        let userA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let userB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let today = VideoTaskDateFormatter.date(from: "2026-08-22")!
        let tomorrow = VideoTaskDateFormatter.date(from: "2026-08-23")!
        let store = InMemoryTimeScopePreferenceStore()

        let videoA = VideoTaskViewModel(
            provider: TestVideoTaskProvider(tasks: []),
            monthValue: "2026-01",
            timeScope: .month,
            selectedDate: VideoTaskDateFormatter.date(from: "2026-01-01")!,
            nowProvider: { today },
            preferenceStore: store
        )
        await videoA.configurePreferenceProfile(userA)
        XCTAssertEqual(videoA.timeScope, .week)
        XCTAssertEqual(CHTimeNavigation.isoString(from: videoA.selectedDate), "2026-08-22")

        await videoA.selectDay(videoA.weekDays.first { $0.isoDate == "2026-08-22" }!)
        XCTAssertEqual(store.load(userID: userA, module: .videoTasks), .day)

        let videoARestore = VideoTaskViewModel(
            provider: TestVideoTaskProvider(tasks: []),
            nowProvider: { tomorrow },
            preferenceStore: store
        )
        await videoARestore.configurePreferenceProfile(userA)
        XCTAssertEqual(videoARestore.timeScope, .day)
        XCTAssertEqual(CHTimeNavigation.isoString(from: videoARestore.selectedDate), "2026-08-23")

        let videoB = VideoTaskViewModel(
            provider: TestVideoTaskProvider(tasks: []),
            nowProvider: { today },
            preferenceStore: store
        )
        await videoB.configurePreferenceProfile(userB)
        XCTAssertEqual(videoB.timeScope, .week)

        let calendarA = CalendarViewModel(
            provider: TestCalendarProvider(shoots: [], editors: []),
            initialDate: today,
            nowProvider: { today },
            preferenceStore: store
        )
        await calendarA.configurePreferenceProfile(userA)
        XCTAssertEqual(calendarA.timeScope, .week)
        await calendarA.selectScope(.month)
        XCTAssertEqual(store.load(userID: userA, module: .calendar), .month)
        XCTAssertEqual(store.load(userID: userA, module: .videoTasks), .day)

        let contentA = ContentPlanViewModel(
            provider: TestContentPlanProvider(items: []),
            nowProvider: { today },
            preferenceStore: store
        )
        await contentA.configurePreferenceProfile(userA)
        XCTAssertEqual(contentA.timeScope, .week)
        await contentA.selectScope(.month)
        XCTAssertEqual(store.load(userID: userA, module: .contentPlan), .month)
    }

    func testPhase11Fix01NavigationAndFilteringRespectLocalCalendarContracts() async {
        let today = VideoTaskDateFormatter.date(from: "2026-08-22")!
        XCTAssertEqual(CHTimeNavigation.calendar.firstWeekday, 2)
        XCTAssertEqual(CHTimeNavigation.calendar.timeZone.identifier, Calendar.autoupdatingCurrent.timeZone.identifier)

        let video = VideoTaskViewModel(
            provider: TestVideoTaskProvider(tasks: [
                videoTask(id: "00000000-0000-0000-0000-000000001151", title: "Monday video", airDate: "2026-08-17"),
                videoTask(id: "00000000-0000-0000-0000-000000001152", title: "Sunday video", airDate: "2026-08-23"),
                videoTask(id: "00000000-0000-0000-0000-000000001153", title: "Next month video", airDate: "2026-09-01")
            ]),
            monthValue: "2026-08",
            timeScope: .week,
            selectedDate: today,
            nowProvider: { today },
            preferenceStore: InMemoryTimeScopePreferenceStore()
        )
        await video.load()
        XCTAssertEqual(video.selectedRange.start, "2026-08-17")
        XCTAssertEqual(video.selectedRange.end, "2026-08-23")
        XCTAssertEqual(video.visibleTasks.map(\.title), ["Monday video", "Sunday video"])

        await video.selectDay(video.weekDays.first { $0.isoDate == "2026-08-23" }!)
        XCTAssertEqual(video.timeScope, .day)
        XCTAssertEqual(video.selectedRange.start, "2026-08-23")
        XCTAssertEqual(video.selectedRange.end, "2026-08-23")
        XCTAssertEqual(video.visibleTasks.map(\.title), ["Sunday video"])

        await video.selectScope(.week)
        await video.shiftWeek(1)
        XCTAssertEqual(video.selectedRange.start, "2026-08-24")
        XCTAssertEqual(video.selectedRange.end, "2026-08-30")
        XCTAssertTrue(video.visibleTasks.isEmpty)

        await video.selectScope(.month)
        XCTAssertEqual(video.selectedRange.start, "2026-08-01")
        XCTAssertEqual(video.selectedRange.end, "2026-08-31")
        XCTAssertEqual(video.visibleTasks.map(\.title), ["Monday video", "Sunday video"])
        await video.shiftMonth(1)
        XCTAssertEqual(video.selectedRange.start, "2026-09-01")
        XCTAssertEqual(video.visibleTasks.map(\.title), ["Next month video"])

        let calendar = CalendarViewModel(
            provider: TestCalendarProvider(shoots: [
                calendarShoot(id: "00000000-0000-0000-0000-000000001161", date: "2026-08-22", content: "Saturday shoot"),
                calendarShoot(id: "00000000-0000-0000-0000-000000001162", date: "2026-08-24", content: "Next week shoot")
            ], editors: []),
            initialDate: today,
            timeScope: .day,
            nowProvider: { today },
            preferenceStore: InMemoryTimeScopePreferenceStore()
        )
        await calendar.load()
        XCTAssertEqual(calendar.visibleShoots.map(\.content), ["Saturday shoot"])

        let content = ContentPlanViewModel(
            provider: TestContentPlanProvider(items: [
                contentPlanItem(id: "00000000-0000-0000-0000-000000001171", airDate: "2026-08-22", title: "Saturday air"),
                contentPlanItem(id: "00000000-0000-0000-0000-000000001172", airDate: "2026-08-24", title: "Next week air")
            ]),
            monthValue: "2026-08",
            timeScope: .day,
            selectedDate: today,
            nowProvider: { today },
            preferenceStore: InMemoryTimeScopePreferenceStore()
        )
        await content.load()
        XCTAssertEqual(content.visibleItems.map(\.title), ["Saturday air"])
    }

    func testPhase8MembersFixtureIdentityAndEditorSemantics() async throws {
        let provider = MemberFixtureRepository(mode: "full")
        let members = try await provider.fetchMembers()

        let dat = try XCTUnwrap(members.first { $0.editorCode == "dat" })
        XCTAssertEqual(dat.role, .admin)
        XCTAssertEqual(dat.id.uuidString, "00000000-0000-0000-0000-000000000801")
        XCTAssertTrue(dat.isEditorMember)
        XCTAssertTrue(dat.isActive)

        let inactive = try XCTUnwrap(members.first { $0.email == "old.editor@company.com" })
        XCTAssertTrue(inactive.isEditorMember)
        XCTAssertFalse(inactive.isActive)
        XCTAssertEqual(inactive.editorCode, "old")
        XCTAssertEqual(inactive.permissionMode, .viewOnly)
    }

    func testPhase8MembersSearchFiltersAndReset() async {
        let viewModel = MembersViewModel(provider: MemberFixtureRepository(mode: "full"))
        await viewModel.load()

        XCTAssertEqual(viewModel.members.count, 6)
        viewModel.searchText = "minh"
        XCTAssertEqual(viewModel.filteredMembers.map(\.editorCode), ["minh"])

        viewModel.searchText = ""
        viewModel.roleFilter = .editor
        viewModel.statusFilter = .inactive
        XCTAssertEqual(viewModel.filteredMembers.map(\.editorCode), ["old"])
        XCTAssertTrue(viewModel.isFiltering)

        viewModel.resetFilters()
        XCTAssertFalse(viewModel.isFiltering)
        XCTAssertEqual(viewModel.filteredMembers.count, 6)
    }

    func testPhase8MembersCreateUpdateDeleteReloadAndValidation() async throws {
        let provider = MemberFixtureRepository(mode: "full")
        let viewModel = MembersViewModel(provider: provider)
        let permissions = MemberPermissions(canView: true, canCreate: true, canUpdate: true, isAdmin: true, currentProfileID: UUID(uuidString: "00000000-0000-0000-0000-000000000801"))

        await viewModel.load()
        viewModel.openCreate()
        viewModel.draft = MemberFormData()
        viewModel.draft.fullName = "Lê Demo"
        viewModel.draft.displayName = "Demo"
        viewModel.draft.email = "demo@company.com"
        viewModel.draft.password = "temporary123"
        viewModel.draft.role = .editor
        viewModel.draft.isEditorMember = true
        viewModel.draft.editorCode = "demo"

        let createToast = await viewModel.save(permissions: permissions)
        XCTAssertEqual(createToast?.message, "Đã tạo thành viên mới.")
        XCTAssertTrue(viewModel.members.contains { $0.editorCode == "demo" })

        let created = try XCTUnwrap(viewModel.members.first { $0.editorCode == "demo" })
        viewModel.open(member: created, permissions: permissions)
        viewModel.draft.displayName = "Demo Updated"
        viewModel.draft.isActive = false
        let updateToast = await viewModel.save(permissions: permissions)
        XCTAssertEqual(updateToast?.message, "Đã lưu thông tin thành viên.")
        XCTAssertEqual(viewModel.members.first { $0.id == created.id }?.displayName, "Demo Updated")
        XCTAssertEqual(viewModel.members.first { $0.id == created.id }?.isActive, false)

        viewModel.pendingDelete = created
        let deleteToast = await viewModel.deletePending(permissions: permissions)
        XCTAssertEqual(deleteToast?.message, "Đã xóa tài khoản.")
        XCTAssertFalse(viewModel.members.contains { $0.id == created.id })
    }

    func testPhase8MembersPermissionsAndSafeErrors() async {
        let currentID = UUID(uuidString: "00000000-0000-0000-0000-000000000801")!
        let current = MemberFixtureRepository.seedMembers[0]
        let other = MemberFixtureRepository.seedMembers[1]
        let permissions = MemberPermissions(canView: true, canCreate: true, canUpdate: true, isAdmin: true, currentProfileID: currentID)

        XCTAssertFalse(current.canDelete(relativeTo: permissions))
        XCTAssertTrue(other.canDelete(relativeTo: permissions))

        let raw = MemberRepositoryError.backend("Fixture SQL Supabase RPC failed")
        XCTAssertEqual(
            MembersViewModel.safeMessage(for: raw, fallback: "Không thể tải danh sách thành viên. Vui lòng thử lại."),
            "Không thể tải danh sách thành viên. Vui lòng thử lại."
        )

        let errorViewModel = MembersViewModel(provider: MemberFixtureRepository(mode: "error"))
        await errorViewModel.load()
        XCTAssertEqual(errorViewModel.loadError, "Không thể tải danh sách thành viên. Vui lòng thử lại.")
    }

    func testPhase8Fix01MembersProductionCopyContract() {
        XCTAssertEqual(MemberCopy.roleStatsHeading, "Vai trò")

        let combinedCopy = [
            MemberCopy.roleStatsHeading,
            MemberCopy.permissionSummarySuffix,
            MemberCopy.deleteConsequence
        ].joined(separator: " ")

        ["PHÒNG BAN", "users_manage", "backend", "admin-only", "RPC", "Edge Function", "SQL", "Supabase", "fixture", "debug", "dữ liệu thử nghiệm"].forEach { forbidden in
            XCTAssertFalse(combinedCopy.localizedCaseInsensitiveContains(forbidden), "Members copy exposes forbidden term: \(forbidden)")
        }

        XCTAssertTrue(MemberCopy.deleteConsequence.localizedCaseInsensitiveContains("tài khoản đăng nhập"))
        XCTAssertTrue(MemberCopy.deleteConsequence.localizedCaseInsensitiveContains("hồ sơ"))
        XCTAssertTrue(MemberCopy.deleteConsequence.localizedCaseInsensitiveContains("phân công"))
    }

    func testPhase8Fix01DeleteFailurePreservesPendingMemberAndDraft() async throws {
        let member = MemberFixtureRepository.seedMembers[1]
        let provider = TestMemberProvider(members: MemberFixtureRepository.seedMembers, deleteResult: .failure(MemberRepositoryError.backend("Fixture SQL delete failed")))
        let viewModel = MembersViewModel(provider: provider)
        let permissions = MemberPermissions(canView: true, canCreate: true, canUpdate: true, isAdmin: true, currentProfileID: UUID(uuidString: "00000000-0000-0000-0000-000000000801"))

        await viewModel.load()
        viewModel.open(member: member, permissions: permissions)
        viewModel.draft.displayName = "Draft Hải"
        viewModel.pendingDelete = member

        let toast = await viewModel.deletePending(permissions: permissions)

        XCTAssertNil(toast)
        XCTAssertEqual(viewModel.pendingDelete?.id, member.id)
        XCTAssertEqual(viewModel.draft.displayName, "Draft Hải")
        XCTAssertEqual(viewModel.moduleMode, .edit(member))
        XCTAssertEqual(viewModel.mutationError, "Không thể xóa tài khoản. Vui lòng thử lại.")
    }

    func testPhase9NotificationTypeAndDestinationMapping() {
        XCTAssertEqual(NotificationSemanticType(rawValue: "shoot_created"), .shootCreated)
        XCTAssertEqual(NotificationSemanticType(rawValue: "future_event"), .unknown)
        XCTAssertEqual(NotificationSemanticType.videoTaskCompleted.iconName, "checkmark.circle")

        let taskID = UUID(uuidString: "00000000-0000-0000-0000-000000000601")!
        XCTAssertEqual(NotificationActionResolver.destination(from: "/tasks?highlight=\(taskID.uuidString)"), .videoTask(taskID))
        XCTAssertEqual(NotificationActionResolver.destination(from: "/video-thang?task=\(taskID.uuidString)"), .videoTask(taskID))
        XCTAssertEqual(NotificationActionResolver.destination(from: "https://example.com/tasks?highlight=\(taskID.uuidString)"), nil)
        XCTAssertFalse(NotificationActionResolver.isSafeExternalLink("javascript:alert(1)"))
        XCTAssertTrue(NotificationActionResolver.isSafeExternalLink("https://creativehub.local"))
    }

    func testPhase9NotificationDTOMapsReadUnreadAndUnknownSafely() throws {
        let data = """
        {
          "id": "00000000-0000-0000-0000-000000000901",
          "recipient_id": "00000000-0000-0000-0000-000000000001",
          "actor_id": null,
          "type": "unknown_future_type",
          "title": "  ",
          "body": "Body copy",
          "entity_type": "video_task",
          "entity_id": "00000000-0000-0000-0000-000000000601",
          "action_url": "/tasks?highlight=00000000-0000-0000-0000-000000000601",
          "metadata": { "priority": true, "count": 2 },
          "event_key": null,
          "read_at": null,
          "created_at": "2026-08-22T03:30:00.000Z"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(NotificationDTO.self, from: data)
        let notification = try XCTUnwrap(dto.notification)

        XCTAssertEqual(notification.type, .unknown)
        XCTAssertEqual(notification.title, "Thông báo")
        XCTAssertTrue(notification.isUnread)
        XCTAssertEqual(notification.entityType, .videoTask)
        XCTAssertEqual(NotificationActionResolver.destination(for: notification), .videoTask(UUID(uuidString: "00000000-0000-0000-0000-000000000601")!))
    }

    func testPhase9NotificationOrderingUnreadCountAndFormatting() {
        let sorted = NotificationFixtureRepository.seedNotifications.sorted(by: NotificationSorter.areInIncreasingOrder)

        XCTAssertEqual(sorted.first?.id, UUID(uuidString: "00000000-0000-0000-0000-000000000901"))
        XCTAssertEqual(NotificationFixtureRepository.seedNotifications.filter(\.isUnread).count, 4)
        XCTAssertEqual(
            NotificationDateFormatter.relative(NotificationFixtureRepository.baseDate.addingTimeInterval(-120), now: NotificationFixtureRepository.baseDate),
            "2 phút trước"
        )
    }

    func testPhase9NotificationViewModelMarkOneReadAndMarkAll() async {
        let provider = NotificationFixtureRepository(mode: "mixed")
        let viewModel = NotificationViewModel(provider: provider)

        await viewModel.load()
        XCTAssertEqual(viewModel.unreadCount, 4)
        let first = try! XCTUnwrap(viewModel.notifications.first(where: { $0.isUnread }))

        let marked = await viewModel.markRead(first)
        XCTAssertTrue(marked)
        XCTAssertEqual(viewModel.notifications.first(where: { $0.id == first.id })?.isUnread, false)
        XCTAssertEqual(viewModel.unreadCount, 3)

        let allMarked = await viewModel.markAllRead()
        XCTAssertTrue(allMarked)
        XCTAssertEqual(viewModel.unreadCount, 0)
        XCTAssertFalse(viewModel.notifications.contains(where: \.isUnread))
    }

    func testPhase9NotificationMarkFailureReconcilesAndSanitizesError() async {
        let provider = NotificationFixtureRepository(mode: "mark-failure")
        let viewModel = NotificationViewModel(provider: provider)

        await viewModel.load()
        let first = try! XCTUnwrap(viewModel.notifications.first(where: { $0.isUnread }))
        let marked = await viewModel.markRead(first)

        XCTAssertFalse(marked)
        XCTAssertEqual(viewModel.mutationError, "Không thể cập nhật trạng thái thông báo.")
        XCTAssertEqual(viewModel.notifications.first(where: { $0.id == first.id })?.isUnread, true)
    }

    func testPhase9NotificationFixtureIsolationAndLoadErrorCopy() async {
        let provider = NotificationFixtureRepository(mode: "error")
        let viewModel = NotificationViewModel(provider: provider)

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .failed("Vui lòng thử lại."))
        XCTAssertFalse(provider.usesProductionData)
    }

    func testPhase10ProfileDTOMapsRoleStatusEditorAndInitials() throws {
        let data = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "email": "hai@creativehub.local",
          "full_name": "Nguyễn Thanh Hải",
          "display_name": null,
          "short_name": "Hải",
          "phone": null,
          "role": "editor",
          "department": null,
          "avatar_url": null,
          "editor_code": "hai",
          "is_editor_member": true,
          "active": true,
          "is_active": true
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(ProfileDTO.self, from: data)
        let profile = dto.profile(fallback: CurrentUserSummary(displayName: "Fallback", email: "fallback@example.test", avatarURL: nil))

        XCTAssertEqual(profile.displayIdentity, "Hải")
        XCTAssertEqual(profile.roleLabel, "Editor")
        XCTAssertEqual(profile.statusLabel, "Đang hoạt động")
        XCTAssertEqual(profile.editorIdentityLabel, "Editor: hai")
        XCTAssertEqual(profile.department, "Team Marketing")
        XCTAssertEqual(ProfileInitials.make(from: "Đoàn Quốc Đạt"), "ĐQ")
    }

    func testPhase10ProfileValidationAndProtectedFieldAllowlist() {
        XCTAssertEqual(ProfileValidation.validate(ProfileDraft(fullName: "", displayName: "Dat", phone: "", department: "Team Marketing")), "Vui lòng nhập họ tên.")
        XCTAssertEqual(ProfileValidation.validate(ProfileDraft(fullName: "Dat", displayName: "", phone: "", department: "Team Marketing")), "Vui lòng nhập tên hiển thị.")
        XCTAssertEqual(ProfileValidation.validate(ProfileDraft(fullName: "Dat", displayName: "Dat", phone: "abc", department: "Team Marketing")), "Số điện thoại chưa đúng định dạng.")
        XCTAssertNil(ProfileValidation.validate(ProfileDraft(fullName: "Dat", displayName: "Dat", phone: "0901 234 567", department: "Team Marketing")))
        XCTAssertEqual(ProfileRoleDisplay.label(for: .creativeManager), "Manager")
    }

    func testPhase10ProfileViewModelSaveReloadsCanonicalAndRefreshesShell() async {
        let provider = ProfileFixtureRepository(mode: "normal")
        let viewModel = ProfileViewModel(provider: provider)
        viewModel.configure(profileID: ProfileFixtureRepository.profileID, fallback: .empty, canEdit: true)

        await viewModel.load()
        viewModel.openEdit()
        viewModel.updateDraft { draft in
            draft.displayName = "Đạt mới"
            draft.phone = "0909 111 222"
        }

        var refreshedName = ""
        let saved = await viewModel.save { profile in
            refreshedName = profile.displayIdentity
        }

        XCTAssertTrue(saved)
        XCTAssertEqual(viewModel.profile?.displayName, "Đạt mới")
        XCTAssertEqual(viewModel.profile?.phone, "0909 111 222")
        XCTAssertEqual(viewModel.sheetState, .none)
        XCTAssertEqual(refreshedName, "Đạt mới")
    }

    func testPhase10ProfileSaveFailurePreservesDraftAndSanitizesError() async {
        let provider = ProfileFixtureRepository(mode: "save-error")
        let viewModel = ProfileViewModel(provider: provider)
        viewModel.configure(profileID: ProfileFixtureRepository.profileID, fallback: .empty, canEdit: true)

        await viewModel.load()
        viewModel.openEdit()
        viewModel.updateDraft { $0.displayName = "Không mất form" }
        let saved = await viewModel.save { _ in }

        XCTAssertFalse(saved)
        XCTAssertEqual(viewModel.draft?.displayName, "Không mất form")
        XCTAssertEqual(viewModel.sheetState, .edit)
        XCTAssertEqual(viewModel.mutationError, "Không thể lưu hồ sơ. Vui lòng thử lại.")
    }

    func testPhase10PasswordValidationAndFixtureIsolation() async {
        XCTAssertEqual(
            ProfileValidation.validatePassword(current: "", next: "abcdefgh", confirm: "abcdefgh"),
            "Vui lòng nhập đầy đủ thông tin mật khẩu."
        )
        XCTAssertEqual(
            ProfileValidation.validatePassword(current: "oldpass1", next: "short", confirm: "short"),
            "Mật khẩu mới cần tối thiểu 8 ký tự."
        )
        XCTAssertEqual(
            ProfileValidation.validatePassword(current: "oldpass1", next: "newpass1", confirm: "nopepass"),
            "Xác nhận mật khẩu mới chưa khớp."
        )

        let provider = ProfileFixtureRepository(mode: "normal")
        let viewModel = ProfileViewModel(provider: provider)
        viewModel.configure(profileID: ProfileFixtureRepository.profileID, fallback: .empty, canEdit: true)
        await viewModel.load()
        viewModel.openPassword()
        viewModel.passwordDraft = PasswordDraft(currentPassword: "oldpass1", newPassword: "newpass1", confirmPassword: "newpass1")

        let changed = await viewModel.changePassword()
        XCTAssertTrue(changed)
        XCTAssertFalse(provider.usesProductionData)
    }

    func testPhase10ProfileLoadErrorCopyAndLogout() async {
        let provider = ProfileFixtureRepository(mode: "load-error")
        let viewModel = ProfileViewModel(provider: provider)
        viewModel.configure(profileID: ProfileFixtureRepository.profileID, fallback: .empty, canEdit: true)

        await viewModel.load()
        XCTAssertEqual(viewModel.loadState, .failed("Vui lòng thử lại."))

        await viewModel.signOut()
        let didSignOut = await provider.didSignOut
        XCTAssertTrue(didSignOut)
    }

    func testPhase10Fix01ProfileReplacementAndFixtureReset() async {
        let provider = ProfileFixtureRepository(mode: "normal")
        let viewModel = ProfileViewModel(provider: provider)
        viewModel.configure(profileID: ProfileFixtureRepository.profileID, fallback: .empty, canEdit: true)

        await viewModel.load()
        XCTAssertEqual(viewModel.profile?.displayName, "Đạt Đoàn")

        viewModel.openEdit()
        viewModel.updateDraft { $0.displayName = "Đạt Phase 10" }
        let saved = await viewModel.save { _ in }
        XCTAssertTrue(saved)
        XCTAssertEqual(viewModel.profile?.displayName, "Đạt Phase 10")
        XCTAssertFalse(viewModel.profile?.displayName.contains("Đạt ĐoànĐạt") ?? true)

        viewModel.openEdit()
        XCTAssertEqual(viewModel.draft?.displayName, "Đạt Phase 10")

        let freshProvider = ProfileFixtureRepository(mode: "normal")
        let freshViewModel = ProfileViewModel(provider: freshProvider)
        freshViewModel.configure(profileID: ProfileFixtureRepository.profileID, fallback: .empty, canEdit: true)
        await freshViewModel.load()
        XCTAssertEqual(freshViewModel.profile?.displayName, "Đạt Đoàn")
    }

    func testPhase10Fix01AvatarUploadRemoveFailureAndScopedPath() async throws {
        let scopedPath = ProfileSupabaseRepository.avatarStoragePath(
            profileID: ProfileFixtureRepository.profileID,
            timestamp: 1_234,
            fileExtension: "PNG"
        )
        XCTAssertEqual(scopedPath, "\(ProfileFixtureRepository.profileID.uuidString)/1234-avatar.png")
        XCTAssertFalse(scopedPath.contains("22222222-2222-2222-2222-222222222222"))

        let provider = ProfileFixtureRepository(mode: "normal")
        let viewModel = ProfileViewModel(provider: provider)
        viewModel.configure(profileID: ProfileFixtureRepository.profileID, fallback: .empty, canEdit: true)
        await viewModel.load()
        viewModel.openEdit()
        viewModel.selectAvatar(data: Data([1, 2, 3]), fileExtension: "png", contentType: "image/png")

        let savedAvatar = await viewModel.save { _ in }
        XCTAssertTrue(savedAvatar)
        let savedURL = try XCTUnwrap(viewModel.profile?.avatarURL?.absoluteString)
        XCTAssertTrue(savedURL.contains(ProfileFixtureRepository.profileID.uuidString))
        XCTAssertTrue(savedURL.hasSuffix("phase10-avatar.png"))

        viewModel.openEdit()
        viewModel.removeAvatar()
        let removedAvatar = await viewModel.save { _ in }
        XCTAssertTrue(removedAvatar)
        XCTAssertNil(viewModel.profile?.avatarURL)
        XCTAssertEqual(viewModel.profile?.initials, "ĐĐ")

        let failingProvider = ProfileFixtureRepository(mode: "avatar-upload-error")
        let failingViewModel = ProfileViewModel(provider: failingProvider)
        failingViewModel.configure(profileID: ProfileFixtureRepository.profileID, fallback: .empty, canEdit: true)
        await failingViewModel.load()
        let originalAvatar = try XCTUnwrap(failingViewModel.profile?.avatarURL)
        failingViewModel.openEdit()
        failingViewModel.selectAvatar(data: Data([7, 8, 9]), fileExtension: "jpg", contentType: "image/jpeg")

        let failed = await failingViewModel.save { _ in }
        XCTAssertFalse(failed)
        XCTAssertEqual(failingViewModel.profile?.avatarURL, originalAvatar)
        XCTAssertEqual(failingViewModel.sheetState, .edit)
        XCTAssertEqual(failingViewModel.mutationError, "Không thể xử lý ảnh đại diện. Vui lòng thử lại.")
    }
}

private actor TestNotificationProvider: NotificationDataProviding {
    nonisolated var usesProductionData: Bool { false }
    var notifications: [InternalNotification]
    var markReadResult: Result<Date, Error>
    var unreadCountError: Error?

    init(notifications: [InternalNotification], markReadResult: Result<Date, Error>, unreadCountError: Error? = nil) {
        self.notifications = notifications
        self.markReadResult = markReadResult
        self.unreadCountError = unreadCountError
    }

    func fetchRecent(limit: Int) async throws -> [InternalNotification] {
        Array(notifications.prefix(limit))
    }

    func unreadCount() async throws -> Int {
        if let unreadCountError {
            throw unreadCountError
        }
        notifications.filter(\.isUnread).count
    }

    func setUnreadCountError(_ error: Error?) {
        unreadCountError = error
    }

    func markRead(id: UUID) async throws -> Date {
        let date = try markReadResult.get()
        notifications = notifications.map { notification in
            guard notification.id == id else { return notification }
            var copy = notification
            copy.readAt = date
            return copy
        }
        return date
    }

    func markAllRead() async throws -> Int {
        let unread = notifications.filter(\.isUnread).count
        let date = Date()
        notifications = notifications.map { notification in
            var copy = notification
            copy.readAt = copy.readAt ?? date
            return copy
        }
        return unread
    }
}

private func contentPlanItem(
    id: String,
    airDate: String = "2026-08-01",
    title: String = "Content Plan Item",
    note: String = "",
    category: ContentPlanCategory = .longForm,
    editorCode: String = "dat",
    link: String = "",
    linkedTaskID: String? = nil,
    linkedTaskStatus: String? = nil
) -> ContentPlanItem {
    let editorProfileID = editorCode.isEmpty ? nil : UUID(uuidString: "11111111-1111-1111-1111-111111111111")
    return ContentPlanItem(
        id: UUID(uuidString: id)!,
        airDate: airDate,
        title: title,
        note: note,
        category: category,
        editorCode: editorCode,
        editorProfileID: editorProfileID,
        editorDisplayName: editorCode.isEmpty ? "Chưa phân công" : "Đạt Đoàn",
        link: link,
        linkedVideoTaskID: linkedTaskID.flatMap(UUID.init(uuidString:)),
        linkedTaskStatus: linkedTaskStatus
    )
}

private final class TestContentPlanProvider: ContentPlanDataProviding, @unchecked Sendable {
    var usesProductionData: Bool { false }
    var items: [ContentPlanItem]
    var editors: [ContentPlanEditorOption]
    var fetchedMonthValues: [String] = []
    var createCount = 0
    var updateCount = 0
    var assignCount = 0
    var deleteCount = 0

    init(items: [ContentPlanItem], editors: [ContentPlanEditorOption]? = nil) {
        self.items = items
        self.editors = editors ?? [
            ContentPlanEditorOption(editorCode: "dat", profileID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Đoàn Quốc Đạt", shortName: "Đạt Đoàn", initials: "Đ", colorHex: "#0EA5E9", avatarURL: nil, role: "admin"),
            ContentPlanEditorOption(editorCode: "hai", profileID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "Nguyễn Thanh Hải", shortName: "Thanh Hải", initials: "H", colorHex: "#22C55E", avatarURL: nil, role: "editor"),
            ContentPlanEditorOption(editorCode: "minh", profileID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, name: "Hoàng Hữu Lê Minh", shortName: "Hữu Minh", initials: "M", colorHex: "#F59E0B", avatarURL: nil, role: "editor")
        ]
    }

    func fetchItems(monthValue: String) async throws -> [ContentPlanItem] {
        fetchedMonthValues.append(monthValue)
        let range = ContentPlanDateFormatter.monthRange(monthValue)
        return items.filter { $0.airDate >= range.start && $0.airDate <= range.end }
    }

    func fetchEditorOptions() async throws -> [ContentPlanEditorOption] {
        editors
    }

    func createItem(_ data: ContentPlanFormData, userID: UUID?) async throws {
        createCount += 1
        items.append(contentPlanItem(id: "00000000-0000-0000-0000-0000000007aa", airDate: data.airDate, title: data.title, note: data.note, category: data.category, editorCode: ""))
    }

    func updateItem(id: UUID, data: ContentPlanFormData, previousItem: ContentPlanItem, userID: UUID?) async throws {
        updateCount += 1
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].title = data.title
            items[index].note = data.note
            items[index].category = data.category
            items[index].airDate = data.airDate
            if !items[index].hasLinkedTask {
                items[index].link = data.link
            }
        }
    }

    func assignEditor(id: UUID, editorCode: String) async throws -> ContentPlanAssignEditorResult {
        assignCount += 1
        let editor = editors.first { $0.editorCode == editorCode }
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].editorCode = editor?.editorCode ?? ""
            items[index].editorProfileID = editor?.profileID
            items[index].editorDisplayName = editor?.shortName ?? "Chưa phân công"
            if items[index].linkedVideoTaskID == nil {
                items[index].linkedVideoTaskID = UUID(uuidString: "00000000-0000-0000-0000-0000000007ab")
                items[index].linkedTaskStatus = "Chờ"
            }
        }
        return ContentPlanAssignEditorResult(
            contentPlanID: id,
            videoTaskID: UUID(uuidString: "00000000-0000-0000-0000-0000000007ab"),
            editorID: editor?.profileID,
            taskCreated: true,
            taskStatus: "Chờ",
            airDate: "2026-08-01"
        )
    }

    func deleteItem(id: UUID) async throws {
        deleteCount += 1
        items.removeAll { $0.id == id }
    }
}

private actor TestMemberProvider: MemberDataProviding {
    nonisolated var usesProductionData: Bool { false }
    var members: [MemberProfile]
    var deleteResult: Result<Void, Error>

    init(members: [MemberProfile], deleteResult: Result<Void, Error> = .success(())) {
        self.members = members
        self.deleteResult = deleteResult
    }

    func fetchMembers() async throws -> [MemberProfile] {
        members
    }

    func createMember(_ data: MemberFormData, actorID: UUID?) async throws {}

    func updateMember(id: UUID, data: MemberFormData, previous: MemberProfile, actorID: UUID?) async throws {}

    func deleteMember(_ member: MemberProfile) async throws {
        try deleteResult.get()
        members.removeAll { $0.id == member.id }
    }

    func resetPassword(member: MemberProfile, password: String) async throws {}
}

private func overviewTask(
    id: String,
    orderTeam: String = "BRAND",
    status: String = "Chờ",
    airDate: String? = "2026-08-01",
    linkedAirDate: String? = nil,
    editorCode: String = "dat",
    editorProfileID: String? = "profile-dat"
) -> OverviewTaskRow {
    OverviewTaskRow(
        id: id,
        title: "Task \(id)",
        orderTeam: orderTeam,
        category: "Video dài",
        status: status,
        resizeRequirements: "",
        receiveDate: airDate,
        returnDate: airDate,
        airDate: airDate,
        linkedAirDate: linkedAirDate,
        resultLink: status == OverviewAggregator.completedStatus ? "https://example.test/\(id)" : "",
        editorCode: editorCode,
        editorProfileID: editorProfileID
    )
}

private func overviewShoot(id: String, date: String, type: String = "lichquay", editorCode: String = "dat") -> OverviewShootRow {
    OverviewShootRow(id: id, shootDate: date, type: type, editorCodes: [editorCode], editorProfileIDs: ["profile-\(editorCode)"])
}

private func calendarShoot(
    id: String,
    date: String = "2026-08-17",
    type: CalendarShootType = .lichquay,
    editorCodes: [String] = ["dat"],
    editorLabels: [String] = ["ĐẠT"],
    crew: String = "BUMI",
    content: String = "Content note title",
    place: String = "SHOWROOM HÒA BÌNH",
    time: String = "ALL MORNING"
) -> CalendarShoot {
    CalendarShoot(
        id: UUID(uuidString: id)!,
        date: CalendarDateFormatter.date(from: date)!,
        type: type,
        crew: crew,
        editorCodes: editorCodes,
        editorProfileIDs: editorCodes.enumerated().map { index, _ in
            UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA\(index)") ?? UUID()
        },
        editorLabels: editorLabels,
        displayCrew: (editorLabels + [crew]).filter { !$0.isEmpty }.joined(separator: " - "),
        place: place,
        content: content,
        time: time,
        note: "Ghi chú"
    )
}

private func videoEditor(
    code: String,
    profileID: String = "11111111-1111-1111-1111-111111111111",
    shortName: String = "Đạt Đoàn"
) -> VideoTaskEditorOption {
    VideoTaskEditorOption(
        editorCode: code,
        profileID: UUID(uuidString: profileID)!,
        name: "Đoàn Quốc Đạt",
        shortName: shortName,
        initials: String(shortName.prefix(1)).uppercased(),
        colorHex: "#0EA5E9",
        avatarURL: nil
    )
}

private func videoTask(
    id: String,
    contentPlanID: String? = nil,
    title: String = "Video QA",
    editorCode: String = "dat",
    editorProfileID: UUID? = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
    orderTeam: String = "BRAND",
    category: VideoTaskCategory = .longForm,
    receiveDate: String? = nil,
    returnDate: String? = nil,
    airDate: String? = "2026-08-12",
    status: VideoTaskStatus = .waiting,
    priority: VideoTaskPriority = .normal,
    resultLink: String = "",
    note: String = "Ghi chú"
) -> VideoTask {
    VideoTask(
        id: UUID(uuidString: id)!,
        contentPlanID: contentPlanID.flatMap(UUID.init(uuidString:)),
        sequence: 1,
        title: title,
        resize: "",
        editorCode: editorCode,
        editorProfileID: editorProfileID,
        editorDisplayName: editorCode == "hai" ? "Thanh Hải" : editorCode == "minh" ? "Hữu Minh" : "Đạt Đoàn",
        orderTeam: orderTeam,
        category: category,
        receiveDate: receiveDate,
        returnDate: returnDate,
        airDate: airDate,
        status: status,
        priority: priority,
        resultLink: resultLink,
        note: note
    )
}

private final class TestCalendarProvider: CalendarDataProviding, @unchecked Sendable {
    enum LoadResult {
        case success
        case failure(Error)
    }

    var usesProductionData: Bool { false }
    var shoots: [CalendarShoot]
    var editors: [CalendarEditorOption]
    var loadResults: [LoadResult]
    var mutationResult: Result<Void, Error>
    var reloadCount = 0
    var lastCreated: CalendarFormData?
    var lastUpdated: (UUID, CalendarFormData)?
    var lastDeleted: UUID?

    init(
        shoots: [CalendarShoot],
        editors: [CalendarEditorOption],
        loadResults: [LoadResult] = [.success],
        mutationResult: Result<Void, Error> = .success(())
    ) {
        self.shoots = shoots
        self.editors = editors
        self.loadResults = loadResults
        self.mutationResult = mutationResult
    }

    func fetchShoots(startDate: String, endDate: String) async throws -> [CalendarShoot] {
        reloadCount += 1
        let result = loadResults.isEmpty ? .success : loadResults.removeFirst()
        if case .failure(let error) = result {
            throw error
        }
        return shoots.filter {
            let iso = CalendarDateFormatter.isoString(from: $0.date)
            return iso >= startDate && iso <= endDate
        }
    }

    func fetchEditorOptions() async throws -> [CalendarEditorOption] {
        if case .failure(let error) = loadResults.first {
            throw error
        }
        return editors
    }

    func createShoot(_ data: CalendarFormData) async throws {
        lastCreated = data
        try mutationResult.get()
        shoots.append(calendarShoot(id: "00000000-0000-0000-0000-000000000099", date: data.date, type: data.type, editorCodes: data.editorCodes, editorLabels: data.editorCodes.map { $0.uppercased() }, crew: data.crew, content: data.content, place: data.place, time: data.time))
    }

    func updateShoot(id: UUID, data: CalendarFormData) async throws {
        lastUpdated = (id, data)
        try mutationResult.get()
        if let index = shoots.firstIndex(where: { $0.id == id }) {
            shoots[index].content = data.content
            shoots[index].note = data.note
        }
    }

    func deleteShoot(id: UUID) async throws {
        lastDeleted = id
        try mutationResult.get()
        shoots.removeAll { $0.id == id }
    }
}

private final class TestVideoTaskProvider: VideoTaskDataProviding, @unchecked Sendable {
    var usesProductionData: Bool { false }
    var tasks: [VideoTask]
    var editors: [VideoTaskEditorOption]
    var mutationResult: Result<Void, Error>
    var fetchCount = 0
    var createCount = 0
    var updateCount = 0
    var deleteCount = 0
    var acceptCount = 0
    var executionCount = 0
    var completeCount = 0
    var deletedLinkedTaskContentPlanID: UUID?
    var fetchedMonthValues: [String] = []

    init(
        tasks: [VideoTask],
        editors: [VideoTaskEditorOption] = [
            videoEditor(code: "dat"),
            videoEditor(code: "hai", profileID: "22222222-2222-2222-2222-222222222222", shortName: "Thanh Hải"),
            videoEditor(code: "minh", profileID: "33333333-3333-3333-3333-333333333333", shortName: "Hữu Minh")
        ],
        mutationResult: Result<Void, Error> = .success(())
    ) {
        self.tasks = tasks
        self.editors = editors
        self.mutationResult = mutationResult
    }

    func fetchTasks(monthValue: String) async throws -> [VideoTask] {
        fetchCount += 1
        fetchedMonthValues.append(monthValue)
        let range = VideoTaskDateFormatter.monthRange(monthValue)
        return tasks.filter {
            guard let airDate = $0.airDate else { return false }
            return airDate >= range.start && airDate <= range.end
        }
    }

    func fetchEditorOptions() async throws -> [VideoTaskEditorOption] {
        editors
    }

    func createTask(_ data: VideoTaskFormData, userID: UUID?) async throws {
        createCount += 1
        try mutationResult.get()
        tasks.append(videoTask(id: "00000000-0000-0000-0000-000000000699", title: data.title, editorCode: data.editorCode, orderTeam: data.orderTeam, category: data.category, airDate: data.airDate.isEmpty ? nil : data.airDate, status: data.status, priority: data.priority, resultLink: data.resultLink, note: data.note))
    }

    func updateTask(id: UUID, data: VideoTaskFormData, previousTask: VideoTask, userID: UUID?, allowLinkedOverride: Bool) async throws {
        updateCount += 1
        try mutationResult.get()
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].title = data.title
            tasks[index].status = data.status
        }
    }

    func deleteTask(_ task: VideoTask, userID: UUID?) async throws {
        deleteCount += 1
        try mutationResult.get()
        deletedLinkedTaskContentPlanID = task.contentPlanID
        tasks.removeAll { $0.id == task.id }
    }

    func acceptLinkedTask(id: UUID, data: VideoTaskAcceptData) async throws {
        acceptCount += 1
        try mutationResult.get()
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].status = .inProgress
            tasks[index].receiveDate = data.receiveDate
            tasks[index].returnDate = data.returnDate
        }
    }

    func updateLinkedExecution(id: UUID, data: VideoTaskExecutionData) async throws {
        executionCount += 1
        try mutationResult.get()
    }

    func completeLinkedTask(id: UUID, resultLink: String) async throws {
        completeCount += 1
        try mutationResult.get()
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].status = .done
            tasks[index].resultLink = resultLink
        }
    }
}

private final class MutableOverviewProvider: OverviewDataProviding, @unchecked Sendable {
    var usesProductionData: Bool { false }
    private var results: [Result<OverviewRawData, Error>]
    private let lock = NSLock()

    init(results: [Result<OverviewRawData, Error>]) {
        self.results = results
    }

    func fetchOverviewRawData(month: OverviewMonth) async throws -> OverviewRawData {
        let result = lock.withLock {
            results.isEmpty ? .success(OverviewRawData(tasks: [], shoots: [], editors: [])) : results.removeFirst()
        }
        return try result.get()
    }
}

private extension OverviewLoadState {
    var errorMessage: String? {
        if case .failed(let message, _) = self {
            return message
        }
        return nil
    }
}

private final class FakeAuthService: AuthServicing, @unchecked Sendable {
    var isConfigured = true
    var restoredSessionResult: Result<AuthenticatedUser?, Error> = .success(nil)
    var signInResult: Result<AuthenticatedUser, Error> = .success(.sample)
    var bootstrapResult: Result<AuthBootstrapResult, Error> = .success(.sample)
    var signOutResult: Result<Void, Error> = .success(())
    var resetResult: Result<Void, Error> = .failure(AuthServiceError.passwordResetUnavailable)
    var restoreCallCount = 0
    var signInCallCount = 0
    var signOutCallCount = 0
    var resetCallCount = 0

    func restoredSessionUser() async throws -> AuthenticatedUser? {
        restoreCallCount += 1
        return try restoredSessionResult.get()
    }

    func signIn(email: String, password: String) async throws -> AuthenticatedUser {
        signInCallCount += 1
        return try signInResult.get()
    }

    func bootstrap(user: AuthenticatedUser) async throws -> AuthBootstrapResult {
        try bootstrapResult.get()
    }

    func signOut() async throws {
        signOutCallCount += 1
        try signOutResult.get()
    }

    func requestPasswordReset(email: String) async throws {
        resetCallCount += 1
        try resetResult.get()
    }
}

private extension AuthenticatedUser {
    static let sample = AuthenticatedUser(
        id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
        email: "dat@example.com",
        metadata: ["full_name": "Dat"]
    )
}

private extension AuthBootstrapResult {
    static let sample = AuthBootstrapResult(
        profile: AuthProfileSummary(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            email: "dat@example.com",
            fullName: "Dat Nguyen",
            displayName: "Dat",
            avatarURL: nil,
            department: "Team Marketing",
            role: .editor,
            rawRole: "editor"
        ),
        permissionOverride: .roleDefault
    )

    static let sampleContentCreator = AuthBootstrapResult(
        profile: AuthProfileSummary(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            email: "creator@example.com",
            fullName: "Creator",
            displayName: "Creator",
            avatarURL: nil,
            department: "Team Marketing",
            role: .contentCreator,
            rawRole: "content_creator"
        ),
        permissionOverride: .roleDefault
    )
}
