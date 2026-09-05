import XCTest

@MainActor
final class CreativeHubUITests: XCTestCase {
    func testLaunchesMainShell() {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08")

        XCTAssertTrue(app.staticTexts["Tổng quan"].waitForExistence(timeout: 5))
    }

    func testPhase1ShellSnapshots() throws {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08")

        XCTAssertTrue(app.staticTexts["Tổng quan"].waitForExistence(timeout: 5))
        try saveScreenshot(named: "01-overview")

        app.buttons["Video"].tap()
        XCTAssertTrue(app.staticTexts["Video"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "02-video")

        app.buttons["Lịch quay"].tap()
        XCTAssertTrue(app.staticTexts["Lịch quay"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "03-calendar-cta")
    }

    func testSecondaryRouteHidesAndRestoresBottomNavigation() throws {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08")

        XCTAssertTrue(app.staticTexts["Tổng quan"].waitForExistence(timeout: 5))
        app.buttons["Thông báo"].tap()

        XCTAssertTrue(app.staticTexts["Thông báo"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Video"].waitForExistence(timeout: 1))
        try saveScreenshot(named: "04-secondary-hidden")

        app.buttons["Quay lại"].tap()
        XCTAssertTrue(app.buttons["Video"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "05-restored-overview")
    }

    func testPhase2AuthSystemStateSnapshots() throws {
        let cases: [(state: String, waitText: String?, waitIdentifier: String?, screenshot: String)] = [
            ("login", "Đăng nhập", nil, "phase2-01-login"),
            ("login-invalid", "Email hoặc mật khẩu chưa chính xác.", nil, "phase2-02-login-invalid"),
            ("loading", nil, "session-bootstrap-logo", "phase2-03-loading-session"),
            ("empty", "Chưa có dữ liệu", nil, "phase2-04-empty"),
            ("load-error", "Không thể tải dữ liệu", nil, "phase2-05-load-error"),
            ("offline", "Không có kết nối mạng", nil, "phase2-06-offline"),
            ("forbidden", "Bạn không có quyền truy cập", nil, "phase2-07-forbidden"),
            ("session-expired", "Phiên đăng nhập đã hết hạn", nil, "phase2-08-session-expired"),
            ("authenticated-shell", "Tổng quan", nil, "phase2-09-authenticated-shell")
        ]

        for testCase in cases {
            let app = XCUIApplication()
            launch(
                app,
                phase2State: testCase.state,
                phase4Fixture: testCase.state == "authenticated-shell" ? "visual" : nil,
                phase4Month: testCase.state == "authenticated-shell" ? "2026-08" : nil
            )
            if let waitText = testCase.waitText {
                XCTAssertTrue(app.staticTexts[waitText].waitForExistence(timeout: 5), "Missing \(waitText)")
            } else if let waitIdentifier = testCase.waitIdentifier {
                XCTAssertTrue(anyElement(waitIdentifier, in: app).waitForExistence(timeout: 5), "Missing \(waitIdentifier)")
            }
            assertPhase2Layout(for: testCase.state, app: app)
            try saveScreenshot(named: testCase.screenshot)
            app.terminate()
        }
    }

    func testPhase2InteractionClosure() throws {
        let login = XCUIApplication()
        launch(login, phase2State: "login")
        XCTAssertTrue(login.staticTexts["Đăng nhập"].waitForExistence(timeout: 5))
        XCTAssertTrue(login.buttons["forgot-password"].waitForExistence(timeout: 2))
        login.buttons["forgot-password"].tap()
        XCTAssertTrue(login.staticTexts["Khôi phục mật khẩu"].waitForExistence(timeout: 2))
        XCTAssertTrue(login.staticTexts["Tính năng khôi phục mật khẩu chưa được cấu hình trên hệ thống. Vui lòng liên hệ quản trị viên để được hỗ trợ."].exists)
        XCTAssertTrue(login.buttons["Đã hiểu"].exists)
        try saveScreenshot(named: "phase2-fix02-forgot-password-info")
        login.buttons["Đã hiểu"].tap()
        XCTAssertTrue(login.staticTexts["Đăng nhập"].waitForExistence(timeout: 2))
        login.terminate()

        for state in ["empty", "load-error", "offline"] {
            let app = XCUIApplication()
            launch(app, phase2State: state)
            XCTAssertTrue(app.descendants(matching: .any)["system-state-title"].waitForExistence(timeout: 5), "Missing title for \(state)")
            XCTAssertFalse(app.buttons["system-state-back"].exists, "\(state) must not expose a no-op back button")
            app.terminate()
        }

        let forbidden = XCUIApplication()
        launch(forbidden, phase2State: "forbidden")
        XCTAssertTrue(forbidden.staticTexts["Bạn không có quyền truy cập"].waitForExistence(timeout: 5))
        XCTAssertTrue(forbidden.buttons["system-state-back"].waitForExistence(timeout: 2))
        forbidden.buttons["system-state-back"].tap()
        XCTAssertTrue(forbidden.staticTexts["Đăng nhập"].waitForExistence(timeout: 5))
        forbidden.terminate()

        let forbiddenAction = XCUIApplication()
        launch(forbiddenAction, phase2State: "forbidden")
        XCTAssertTrue(forbiddenAction.staticTexts["Bạn không có quyền truy cập"].waitForExistence(timeout: 5))
        XCTAssertTrue(forbiddenAction.buttons["system-state-secondary-action"].waitForExistence(timeout: 2))
        forbiddenAction.buttons["system-state-secondary-action"].tap()
        XCTAssertTrue(forbiddenAction.staticTexts["Đăng nhập"].waitForExistence(timeout: 5))
        forbiddenAction.terminate()

        let sessionExpired = XCUIApplication()
        launch(sessionExpired, phase2State: "session-expired")
        XCTAssertTrue(sessionExpired.staticTexts["Phiên đăng nhập đã hết hạn"].waitForExistence(timeout: 5))
        XCTAssertFalse(sessionExpired.buttons["system-state-back"].exists)
        sessionExpired.buttons["system-state-primary-action"].tap()
        XCTAssertTrue(sessionExpired.staticTexts["Đăng nhập"].waitForExistence(timeout: 5))
        sessionExpired.terminate()
    }

    func testPhase3AppShellNavigationSnapshots() throws {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase3QAHarness: true, phase4Fixture: "visual", phase4Month: "2026-08", phase10Fixture: "normal")

        XCTAssertTrue(app.buttons["navbar.overview"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["topbar.more"].exists)
        try saveScreenshot(named: "phase3-01-overview-shell")

        app.buttons["navbar.video"].tap()
        XCTAssertEqual(app.staticTexts["topbar.title"].label, "Video tháng")
        XCTAssertTrue(app.buttons["navbar.video"].exists)
        XCTAssertEqual(app.buttons["navbar.video"].label, "Video")
        XCTAssertTrue(app.staticTexts["Video"].waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("tool-reveal.state.video.closed", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase3-02-video-tools-closed")
        try saveScreenshot(named: "phase3-fix01-01-video-title")

        app.buttons["topbar.more"].tap()
        XCTAssertTrue(anyElement("tool-reveal.state.video.open", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["tool-reveal.search.video"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase3-03-video-tools-open")

        app.buttons["navbar.calendar"].tap()
        XCTAssertTrue(app.staticTexts["Lịch quay"].waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("tool-reveal.state.calendar.closed", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase3-04-calendar-selected")

        app.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("tool-reveal.state.video.open", in: app).waitForExistence(timeout: 2))
        app.buttons["topbar.notifications"].tap()
        XCTAssertTrue(anyElement("secondary.notifications", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["navbar.video"].waitForExistence(timeout: 1))
        try saveScreenshot(named: "phase3-05-notifications-from-video")

        app.buttons["topbar.back"].tap()
        XCTAssertTrue(app.buttons["navbar.video"].waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("tool-reveal.state.video.open", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase3-06-restored-video")

        app.buttons["navbar.calendar"].tap()
        app.buttons["topbar.profile"].tap()
        XCTAssertTrue(anyElement("secondary.profile", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["navbar.calendar"].waitForExistence(timeout: 1))
        XCTAssertTrue(anyElement("profile.root", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("profile.summary", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase3-07-profile-from-calendar")
        try saveScreenshot(named: "phase3-fix01-02-profile-shell-placeholder")

        app.buttons["topbar.back"].tap()
        XCTAssertTrue(app.buttons["navbar.calendar"].waitForExistence(timeout: 2))
        app.buttons["topbar.more"].tap()
        XCTAssertTrue(anyElement("tool-reveal.state.calendar.open", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["calendar.filter.all"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.textFields["tool-reveal.search.calendar"].exists)
        try saveScreenshot(named: "phase3-09-module-restored")
        try saveScreenshot(named: "phase3-fix01-05-restored-calendar")

        app.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("tool-reveal.state.video.open", in: app).waitForExistence(timeout: 2))
        app.buttons["phase3.show-toast"].tap()
        XCTAssertTrue(anyElement("toast", in: app).waitForExistence(timeout: 2))
        XCTAssertGreaterThan(anyElement("toast", in: app).frame.minY, app.frame.height - 190)
        try saveScreenshot(named: "phase3-10-toast-navbar-visible")
        try saveScreenshot(named: "phase3-fix01-03-toast-navbar-visible")
    }

    func testPhase3PeerTabsToolIsolationAndRepeatedTap() {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08")

        XCTAssertTrue(app.buttons["navbar.video"].waitForExistence(timeout: 5))
        app.buttons["navbar.video"].tap()
        app.buttons["topbar.more"].tap()
        XCTAssertTrue(anyElement("tool-reveal.state.video.open", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["module.open-test"].exists)

        app.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("tool-reveal.state.content.closed", in: app).waitForExistence(timeout: 2))
        app.buttons["navbar.content"].tap()
        XCTAssertFalse(app.buttons["topbar.back"].exists)

        app.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("tool-reveal.state.video.open", in: app).waitForExistence(timeout: 2))
    }

    func testPhase3AuthStatesDoNotShowAuthenticatedShellRoutes() {
        let app = XCUIApplication()
        launch(app, phase2State: "login")

        XCTAssertTrue(app.staticTexts["Đăng nhập"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["topbar.notifications"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["module.scaffold"].exists)
        XCTAssertFalse(app.buttons["navbar.calendar"].exists)
    }

    func testPhase4OverviewDashboardSnapshots() throws {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08")

        XCTAssertTrue(anyElement("overview.dashboard", in: app).waitForExistence(timeout: 5))
        try saveScreenshot(named: "phase4-01-overview-full-top")

        try saveScreenshot(named: "phase4-02-overview-team-order")
        try saveScreenshot(named: "phase4-fix01-03-team-order")

        try saveScreenshot(named: "phase4-03-overview-editor-workload")

        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        try saveScreenshot(named: "phase4-fix01-01-editor-workload-full")
        try saveScreenshot(named: "phase4-04-overview-bottom-metrics")
        try saveScreenshot(named: "phase4-fix01-02-shoot-load-no-ratio")

        app.buttons["topbar.notifications"].tap()
        XCTAssertTrue(anyElement("secondary.notifications", in: app).waitForExistence(timeout: 2))
        app.buttons["topbar.back"].tap()
        XCTAssertTrue(anyElement("overview.dashboard", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase4-07-overview-restored-from-notifications")
    }

    func testPhase4OverviewZeroDataAndErrorSnapshots() throws {
        let zero = XCUIApplication()
        launch(zero, phase2State: "authenticated-shell", phase4Fixture: "zero", phase4Month: "2026-08")
        Thread.sleep(forTimeInterval: 1.5)
        try saveScreenshot(named: "phase4-05-overview-zero-data")
        try saveScreenshot(named: "phase4-fix01-04-zero-data-bottom")
        zero.terminate()

        let error = XCUIApplication()
        launch(error, phase2State: "authenticated-shell", phase4Fixture: "error", phase4Month: "2026-08")
        XCTAssertTrue(anyElement("overview.load-error", in: error).waitForExistence(timeout: 5))
        XCTAssertTrue(error.buttons["Thử lại"].exists)
        XCTAssertTrue(error.buttons["navbar.overview"].exists)
        try saveScreenshot(named: "phase4-06-overview-load-error")
        error.terminate()
    }

    func testPhase5CalendarSnapshots() throws {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase5Fixture: "full", phase5Date: "2026-08-17")
        app.buttons["navbar.calendar"].tap()
        XCTAssertTrue(anyElement("calendar.root", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("calendar.agenda-list", in: app).waitForExistence(timeout: 5))
        try saveScreenshot(named: "phase5-01-calendar-main")

        app.buttons["topbar.more"].tap()
        XCTAssertTrue(app.buttons["calendar.filter.all"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase5-02-calendar-filters-open")

        app.buttons["calendar.filter.onset"].tap()
        XCTAssertTrue(app.staticTexts["On set"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase5-03-calendar-onset-filter")

        app.buttons["calendar.filter.all"].tap()
        XCTAssertTrue(app.buttons["calendar.add"].waitForExistence(timeout: 2))
        app.buttons["calendar.add"].tap()
        XCTAssertTrue(anyElement("calendar.module", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["navbar.calendar"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Thêm lịch quay"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase5-04-calendar-create-module")
        app.buttons["module.back"].tap()
        XCTAssertTrue(app.buttons["navbar.calendar"].waitForExistence(timeout: 2))

        XCTAssertTrue(anyElement("calendar.agenda.00000000-0000-0000-0000-000000000002", in: app).waitForExistence(timeout: 2))
        anyElement("calendar.agenda.00000000-0000-0000-0000-000000000002", in: app).tap()
        XCTAssertTrue(app.staticTexts["Chỉnh sửa lịch quay"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase5-05-calendar-edit-module")

        XCTAssertTrue(anyElement("calendar.module.delete", in: app).waitForExistence(timeout: 2))
        anyElement("calendar.module.delete", in: app).tap()
        XCTAssertTrue(anyElement("calendar.delete.confirm", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase5-07-calendar-delete-confirm")
        app.buttons["Hủy"].tap()

        app.buttons["calendar.module.save"].tap()
        XCTAssertTrue(app.buttons["navbar.calendar"].waitForExistence(timeout: 3))
        XCTAssertTrue(anyElement("toast", in: app).waitForExistence(timeout: 3))
        try saveScreenshot(named: "phase5-08-calendar-restored-toast")
        app.terminate()

        let readonly = XCUIApplication()
        launch(readonly, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase5Fixture: "readonly", phase5Date: "2026-08-17", phase5Permission: "readonly")
        readonly.buttons["navbar.calendar"].tap()
        XCTAssertTrue(anyElement("calendar.agenda.00000000-0000-0000-0000-000000000002", in: readonly).waitForExistence(timeout: 5))
        anyElement("calendar.agenda.00000000-0000-0000-0000-000000000002", in: readonly).tap()
        XCTAssertTrue(readonly.staticTexts["Chi tiết lịch quay"].waitForExistence(timeout: 2))
        XCTAssertFalse(readonly.buttons["calendar.module.save"].exists)
        try saveScreenshot(named: "phase5-06-calendar-readonly-detail")
        readonly.terminate()

        let empty = XCUIApplication()
        launch(empty, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase5Fixture: "empty", phase5Date: "2026-08-17")
        empty.buttons["navbar.calendar"].tap()
        XCTAssertTrue(anyElement("calendar.month-empty", in: empty).waitForExistence(timeout: 5))
        try saveScreenshot(named: "phase5-09-calendar-empty")
        empty.terminate()

        let error = XCUIApplication()
        launch(error, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase5Fixture: "error", phase5Date: "2026-08-17")
        error.buttons["navbar.calendar"].tap()
        XCTAssertTrue(anyElement("calendar.load-error", in: error).waitForExistence(timeout: 5))
        XCTAssertTrue(error.buttons["Thử lại"].exists)
        try saveScreenshot(named: "phase5-10-calendar-load-error")
        error.terminate()

        let filterEmpty = XCUIApplication()
        launch(filterEmpty, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase5Fixture: "filter-empty", phase5Date: "2026-08-17")
        filterEmpty.buttons["navbar.calendar"].tap()
        XCTAssertTrue(anyElement("calendar.agenda-list", in: filterEmpty).waitForExistence(timeout: 5))
        filterEmpty.buttons["topbar.more"].tap()
        XCTAssertTrue(anyElement("calendar.filter-strip", in: filterEmpty).waitForExistence(timeout: 2))
        anyElement("calendar.filter-strip", in: filterEmpty).swipeLeft()
        XCTAssertTrue(filterEmpty.buttons["calendar.filter.other"].waitForExistence(timeout: 2))
        filterEmpty.buttons["calendar.filter.other"].tap()
        XCTAssertTrue(anyElement("calendar.filter-empty", in: filterEmpty).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase5-11-calendar-filter-empty")
        filterEmpty.terminate()
    }

    func testPhase5Fix01ReadonlyAndCanonicalCrewSnapshots() throws {
        let readonly = XCUIApplication()
        launch(readonly, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase5Fixture: "readonly", phase5Date: "2026-08-17", phase5Permission: "readonly")
        readonly.buttons["navbar.calendar"].tap()
        let readonlyCard = anyElement("calendar.agenda.00000000-0000-0000-0000-000000000002", in: readonly)
        XCTAssertTrue(readonlyCard.waitForExistence(timeout: 5))
        readonlyCard.tap()
        XCTAssertTrue(readonly.staticTexts["Chi tiết lịch quay"].waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("calendar.module.type.passive", in: readonly).waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("calendar.module.editor.passive.dat", in: readonly).waitForExistence(timeout: 2))
        XCTAssertFalse(readonly.buttons["calendar.module.type.livestream"].exists)
        XCTAssertFalse(readonly.buttons["calendar.module.type.lichquay"].exists)
        XCTAssertFalse(anyElement("calendar.module.editor.selection-control", in: readonly).exists)
        XCTAssertFalse(readonly.buttons["calendar.module.save"].exists)
        XCTAssertFalse(readonly.buttons["calendar.module.delete"].exists)
        XCTAssertTrue(anyElement("calendar.module.passive-field", in: readonly).exists)
        try saveScreenshot(named: "phase5-fix01-01-readonly-detail")
        readonly.terminate()

        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase5Fixture: "full", phase5Date: "2026-08-17")
        app.buttons["navbar.calendar"].tap()
        let targetCard = anyElement("calendar.agenda.00000000-0000-0000-0000-000000000002", in: app)
        XCTAssertTrue(targetCard.waitForExistence(timeout: 5))
        XCTAssertTrue(targetCard.label.contains("ĐẠT - MINH - BUMI"))
        try saveScreenshot(named: "phase5-fix01-03-canonical-crew-before")

        targetCard.tap()
        XCTAssertTrue(app.staticTexts["Chỉnh sửa lịch quay"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["calendar.module.type.livestream"].exists)
        XCTAssertTrue(app.buttons["calendar.module.type.lichquay"].exists)
        XCTAssertTrue(app.buttons["calendar.module.type.onset"].exists)
        XCTAssertTrue(app.buttons["calendar.module.type.other"].exists)
        XCTAssertTrue(anyElement("calendar.module.editor.selection-control", in: app).exists)
        XCTAssertTrue(anyElement("calendar.module.save", in: app).exists)
        XCTAssertTrue(anyElement("calendar.module.delete", in: app).exists)
        try saveScreenshot(named: "phase5-fix01-02-edit-mode-preserved")

        anyElement("calendar.module.save", in: app).tap()
        XCTAssertTrue(app.buttons["navbar.calendar"].waitForExistence(timeout: 3))
        XCTAssertTrue(anyElement("toast", in: app).waitForExistence(timeout: 3))
        let updatedCard = anyElement("calendar.agenda.00000000-0000-0000-0000-000000000002", in: app)
        XCTAssertTrue(updatedCard.waitForExistence(timeout: 2))
        XCTAssertTrue(updatedCard.label.contains("ĐẠT - MINH - BUMI"))
        XCTAssertFalse(updatedCard.label.contains("ĐẠT ĐOÀN - HỮU MINH - BUMI"))
        try saveScreenshot(named: "phase5-fix01-04-canonical-crew-after-toast")
        app.terminate()
    }

    func testPhase6VideoTaskSnapshots() throws {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase6Fixture: "full", phase6Month: "2026-08")
        app.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("video.task.00000000-0000-0000-0000-000000000601", in: app).exists)
        try saveScreenshot(named: "phase6-01-video-main")

        app.buttons["topbar.more"].tap()
        XCTAssertTrue(anyElement("tool-reveal.state.video.open", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["tool-reveal.search.video"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase6-02-video-tools-open")

        app.buttons["video.filter.status.done"].tap()
        XCTAssertTrue(anyElement("video.task.00000000-0000-0000-0000-000000000601", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase6-03-video-filtered")

        app.buttons["video.filter.status.all"].tap()
        XCTAssertTrue(app.buttons["video.add"].waitForExistence(timeout: 2))
        app.buttons["video.add"].tap()
        XCTAssertTrue(anyElement("video.module", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Thêm Task mới"].waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("video.module.title", in: app).exists)
        try saveScreenshot(named: "phase6-04-video-create")
        app.buttons["module.back"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: app).waitForExistence(timeout: 2))

        tapStaticText("Video Review IKI Premium", in: app)
        XCTAssertTrue(app.staticTexts["Chỉnh sửa Task"].waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("video.module.save", in: app).exists)
        XCTAssertTrue(anyElement("video.module.delete", in: app).exists)
        try saveScreenshot(named: "phase6-05-video-edit-standalone")
        app.buttons["module.back"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: app).waitForExistence(timeout: 2))

        app.terminate()

        let editor = XCUIApplication()
        launch(editor, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase6Fixture: "full", phase6Month: "2026-08", phase6Permission: "update")
        editor.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: editor).waitForExistence(timeout: 5))

        tapStaticText("CP: Ưu đãi nệm tháng 8", in: editor)
        XCTAssertTrue(editor.staticTexts["Nhận Task"].waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("video.module.accept", in: editor).exists)
        XCTAssertTrue(anyElement("video.module.title.passive", in: editor).exists)
        try saveScreenshot(named: "phase6-06-video-linked-waiting-accept")
        editor.buttons["module.back"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: editor).waitForExistence(timeout: 2))

        tapStaticText("CP: Motion BST phòng ngủ", in: editor)
        XCTAssertTrue(editor.staticTexts["Hoàn thành Task"].waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("video.module.save-execution", in: editor).exists)
        XCTAssertTrue(anyElement("video.module.complete", in: editor).exists)
        try saveScreenshot(named: "phase6-07-video-linked-in-progress")
        editor.buttons["module.back"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: editor).waitForExistence(timeout: 2))

        tapStaticText("CP: Video khác editor", in: editor, maxSwipes: 3)
        XCTAssertTrue(editor.staticTexts["Chi tiết Task"].waitForExistence(timeout: 2))
        XCTAssertFalse(anyElement("video.module.accept", in: editor).exists)
        XCTAssertFalse(anyElement("video.module.complete", in: editor).exists)
        XCTAssertFalse(anyElement("video.module.save", in: editor).exists)
        try saveScreenshot(named: "phase6-08-video-linked-other-editor")
        editor.terminate()

        let deleting = XCUIApplication()
        launch(deleting, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase6Fixture: "full", phase6Month: "2026-08")
        deleting.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: deleting).waitForExistence(timeout: 5))
        tapStaticText("CP: Ưu đãi nệm tháng 8", in: deleting)
        XCTAssertTrue(anyElement("video.module.delete", in: deleting).waitForExistence(timeout: 2))
        anyElement("video.module.delete", in: deleting).tap()
        XCTAssertTrue(deleting.staticTexts["Xóa video task?"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase6-09-video-delete-confirm")
        deleting.buttons["video.delete.confirm"].tap()
        XCTAssertTrue(deleting.buttons["navbar.video"].waitForExistence(timeout: 3))
        XCTAssertTrue(anyElement("toast", in: deleting).waitForExistence(timeout: 3))
        try saveScreenshot(named: "phase6-10-video-restored-toast")
        deleting.terminate()

        let empty = XCUIApplication()
        launch(empty, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase6Fixture: "empty", phase6Month: "2026-08")
        empty.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.month-empty", in: empty).waitForExistence(timeout: 5))
        try saveScreenshot(named: "phase6-11-video-empty")
        empty.terminate()

        let filterEmpty = XCUIApplication()
        launch(filterEmpty, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase6Fixture: "full", phase6Month: "2026-08")
        filterEmpty.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: filterEmpty).waitForExistence(timeout: 5))
        filterEmpty.buttons["topbar.more"].tap()
        XCTAssertTrue(filterEmpty.textFields["tool-reveal.search.video"].waitForExistence(timeout: 2))
        filterEmpty.textFields["tool-reveal.search.video"].tap()
        filterEmpty.textFields["tool-reveal.search.video"].typeText("khongco")
        if filterEmpty.keyboards.buttons["return"].exists {
            filterEmpty.keyboards.buttons["return"].tap()
        }
        XCTAssertTrue(anyElement("video.filter-empty", in: filterEmpty).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase6-12-video-filter-empty")
        filterEmpty.terminate()

        let error = XCUIApplication()
        launch(error, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase6Fixture: "error", phase6Month: "2026-08")
        error.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.load-error", in: error).waitForExistence(timeout: 5))
        XCTAssertTrue(error.buttons["Thử lại"].exists)
        try saveScreenshot(named: "phase6-13-video-load-error")
        error.terminate()

        let readonly = XCUIApplication()
        launch(readonly, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase6Fixture: "full", phase6Month: "2026-08", phase6Permission: "readonly")
        readonly.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: readonly).waitForExistence(timeout: 5))
        XCTAssertFalse(readonly.buttons["video.add"].exists)
        XCTAssertFalse(anyElement("video.task.delete.00000000-0000-0000-0000-000000000601", in: readonly).exists)
        try saveScreenshot(named: "phase6-14-video-readonly-permissions")
        readonly.terminate()

        let completed = XCUIApplication()
        launch(completed, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase6Fixture: "full", phase6Month: "2026-08")
        completed.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: completed).waitForExistence(timeout: 5))
        completed.buttons["topbar.more"].tap()
        XCTAssertTrue(anyElement("tool-reveal.state.video.open", in: completed).waitForExistence(timeout: 2))
        completed.buttons["video.filter.status.done"].tap()
        XCTAssertTrue(anyElement("video.task.00000000-0000-0000-0000-000000000601", in: completed).waitForExistence(timeout: 2))
        XCTAssertTrue(completed.buttons["Link"].exists)
        try saveScreenshot(named: "phase6-15-video-completed-link")
        completed.terminate()
    }

    func testPhase6Fix01UXStateClosureSnapshots() throws {
        let tools = XCUIApplication()
        launch(tools, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase6Fixture: "full", phase6Month: "2026-08")
        tools.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: tools).waitForExistence(timeout: 5))
        tools.buttons["topbar.more"].tap()
        XCTAssertTrue(anyElement("tool-reveal.state.video.open", in: tools).waitForExistence(timeout: 2))
        XCTAssertTrue(tools.textFields["tool-reveal.search.video"].waitForExistence(timeout: 2))
        XCTAssertTrue(tools.buttons["video.filter.editor.menu"].exists)
        XCTAssertTrue(tools.buttons["video.filter.order.menu"].exists)
        XCTAssertTrue(tools.buttons["video.filter.category.menu"].exists)
        try saveScreenshot(named: "phase6-fix01-01-video-tools-compact")
        tools.buttons["video.filter.editor.menu"].tap()
        tools.buttons["Hữu Minh"].tap()
        XCTAssertTrue(tools.buttons["Editor · Hữu Minh"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase6-fix01-02-video-filter-active")
        tools.terminate()

        let other = XCUIApplication()
        launch(other, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase6Fixture: "full", phase6Month: "2026-08", phase6Permission: "update")
        other.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: other).waitForExistence(timeout: 5))
        tapStaticText("CP: Video khác editor", in: other, maxSwipes: 3)
        XCTAssertTrue(other.staticTexts["Chi tiết Task"].waitForExistence(timeout: 2))
        XCTAssertFalse(anyElement("video.module.accept", in: other).exists)
        XCTAssertFalse(anyElement("video.module.complete", in: other).exists)
        XCTAssertFalse(anyElement("video.module.save", in: other).exists)
        try saveScreenshot(named: "phase6-fix01-03-linked-other-editor-detail")
        other.terminate()

        let deleting = XCUIApplication()
        launch(deleting, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase6Fixture: "full", phase6Month: "2026-08", phase6Permission: "update-delete")
        deleting.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: deleting).waitForExistence(timeout: 5))
        tapStaticText("CP: Ưu đãi nệm tháng 8", in: deleting)
        XCTAssertTrue(deleting.staticTexts["Nhận Task"].waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("video.module.accept", in: deleting).exists)
        XCTAssertTrue(anyElement("video.module.delete", in: deleting).exists)
        anyElement("video.module.delete", in: deleting).tap()
        XCTAssertTrue(deleting.staticTexts["Xóa video task?"].waitForExistence(timeout: 2))
        XCTAssertTrue(deleting.staticTexts["Nhận Task"].exists)
        try saveScreenshot(named: "phase6-fix01-04-linked-accept-delete-confirm")
        deleting.buttons["video.delete.cancel"].tap()
        XCTAssertTrue(deleting.staticTexts["Nhận Task"].waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("video.module.accept", in: deleting).exists)
        try saveScreenshot(named: "phase6-fix01-05-linked-accept-after-cancel")
        deleting.terminate()

        let month = XCUIApplication()
        launch(month, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase6Fixture: "full", phase6Month: "2026-08", phase6Permission: "update-delete")
        month.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: month).waitForExistence(timeout: 5))
        XCTAssertTrue(month.buttons["video.month.prev"].exists)
        XCTAssertTrue(month.buttons["video.month.next"].exists)
        try saveScreenshot(named: "phase6-fix01-06-month-navigation-contrast")
        let finalTitle = month.staticTexts["Video nội bộ tuyển dụng"]
        var scrollAttempts = 0
        while (!finalTitle.isHittable || finalTitle.frame.maxY >= month.frame.height - 86) && scrollAttempts < 6 {
            month.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
            scrollAttempts += 1
        }
        XCTAssertTrue(finalTitle.exists)
        XCTAssertLessThan(finalTitle.frame.maxY, month.frame.height - 86)
        try saveScreenshot(named: "phase6-fix01-07-video-bottom-scroll-safe")
        XCTAssertTrue(finalTitle.isHittable)
        finalTitle.tap()
        XCTAssertTrue(month.staticTexts["Chỉnh sửa Task"].waitForExistence(timeout: 2))
        month.terminate()
    }

    func testPhase7ContentPlanMainAndFilterSnapshots() throws {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "full", phase7Month: "2026-08")
        app.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.plan-list", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("content.plan.00000000-0000-0000-0000-000000000701", in: app).exists)
        try saveScreenshot(named: "phase7-01-content-main")

        app.buttons["topbar.more"].tap()
        XCTAssertTrue(anyElement("tool-reveal.state.content.open", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["tool-reveal.search.content"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase7-02-content-tools-open")

        app.buttons["content.filter.category.motion"].tap()
        XCTAssertTrue(anyElement("content.plan.00000000-0000-0000-0000-000000000702", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase7-03-content-filtered")
        app.terminate()
    }

    func testPhase7ContentPlanCreateAndEditSnapshots() throws {
        let create = XCUIApplication()
        launch(create, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "full", phase7Month: "2026-08", phase7Permission: "create-only")
        create.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.plan-list", in: create).waitForExistence(timeout: 5))
        XCTAssertTrue(create.buttons["content.add"].waitForExistence(timeout: 2))
        create.buttons["content.add"].tap()
        XCTAssertTrue(anyElement("content.module", in: create).waitForExistence(timeout: 2))
        XCTAssertTrue(create.staticTexts["Thêm lịch air"].waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("content.module.title", in: create).exists)
        try saveScreenshot(named: "phase7-04-content-create")
        create.terminate()

        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "full", phase7Month: "2026-08", phase7Permission: "update-assign-delete")
        app.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.plan-list", in: app).waitForExistence(timeout: 5))
        tapStaticText("Video khai trương showroom Cần Thơ", in: app)
        XCTAssertTrue(app.staticTexts["Sửa lịch air"].waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("content.module.save", in: app).exists)
        XCTAssertTrue(anyElement("content.module.delete", in: app).exists)
        try saveScreenshot(named: "phase7-05-content-edit")
        app.buttons["module.back"].tap()
        XCTAssertTrue(anyElement("content.plan-list", in: app).waitForExistence(timeout: 2))
        app.terminate()
    }

    func testPhase7ContentPlanReadonlySnapshot() throws {
        let readonly = XCUIApplication()
        launch(readonly, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "full", phase7Month: "2026-08", phase7Permission: "readonly")
        readonly.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.plan-list", in: readonly).waitForExistence(timeout: 5))
        tapStaticText("Video khai trương showroom Cần Thơ", in: readonly)
        XCTAssertTrue(readonly.staticTexts["Chi tiết Content"].waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("content.module.title.passive", in: readonly).exists)
        XCTAssertTrue(anyElement("content.module.editor.passive", in: readonly).exists)
        XCTAssertFalse(anyElement("content.module.save", in: readonly).exists)
        try saveScreenshot(named: "phase7-06-content-readonly")
        readonly.terminate()
    }

    func testPhase7ContentPlanLinkedDeleteSnapshots() throws {
        let linked = XCUIApplication()
        launch(linked, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "full", phase7Month: "2026-08", phase7Permission: "update-assign-delete")
        linked.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.plan-list", in: linked).waitForExistence(timeout: 5))
        tapStaticText("Motion ưu đãi nệm tháng 8", in: linked)
        XCTAssertTrue(linked.staticTexts["Sửa lịch air"].waitForExistence(timeout: 2))
        XCTAssertTrue(linked.staticTexts["Link này được đồng bộ từ Video tháng."].exists)
        XCTAssertTrue(anyElement("content.module.link.passive", in: linked).exists)
        try saveScreenshot(named: "phase7-07-content-linked-video-task")
        linked.buttons["content.module.delete"].tap()
        XCTAssertTrue(anyElement("content.delete.confirmation", in: linked).waitForExistence(timeout: 2))
        XCTAssertTrue(linked.staticTexts["Xóa kế hoạch content?"].exists)
        try saveScreenshot(named: "phase7-08-content-delete-confirm")
        linked.buttons["Xóa dòng"].tap()
        XCTAssertTrue(linked.buttons["navbar.content"].waitForExistence(timeout: 3))
        XCTAssertTrue(anyElement("toast", in: linked).waitForExistence(timeout: 3))
        try saveScreenshot(named: "phase7-09-content-restored-toast")
        linked.terminate()
    }

    func testPhase7ContentPlanEmptyAndErrorSnapshots() throws {
        let empty = XCUIApplication()
        launch(empty, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "empty", phase7Month: "2026-08", phase7Permission: "update-assign-delete")
        empty.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.month-empty", in: empty).waitForExistence(timeout: 5))
        try saveScreenshot(named: "phase7-10-content-empty")
        empty.terminate()

        let filterEmpty = XCUIApplication()
        launch(filterEmpty, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "full", phase7Month: "2026-08", phase7Permission: "update-assign-delete")
        filterEmpty.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.plan-list", in: filterEmpty).waitForExistence(timeout: 5))
        filterEmpty.buttons["topbar.more"].tap()
        XCTAssertTrue(filterEmpty.textFields["tool-reveal.search.content"].waitForExistence(timeout: 2))
        filterEmpty.textFields["tool-reveal.search.content"].tap()
        filterEmpty.textFields["tool-reveal.search.content"].typeText("khongco")
        if filterEmpty.keyboards.buttons["return"].exists {
            filterEmpty.keyboards.buttons["return"].tap()
        }
        XCTAssertTrue(anyElement("content.filter-empty", in: filterEmpty).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase7-11-content-filter-empty")
        filterEmpty.terminate()

        let error = XCUIApplication()
        launch(error, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "error", phase7Month: "2026-08")
        error.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.load-error", in: error).waitForExistence(timeout: 5))
        XCTAssertTrue(error.buttons["Thử lại"].exists)
        try saveScreenshot(named: "phase7-12-content-load-error")
        error.terminate()
    }

    func testPhase7Fix01ContentPlanCanonicalSnapshots() throws {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "full", phase7Month: "2026-08", phase7Permission: "update-assign-delete")
        app.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.plan-list", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Team Order"].exists)
        XCTAssertTrue(app.staticTexts["Không tạo Video Task"].exists)
        try saveScreenshot(named: "phase7-fix01-01-content-main-canonical")

        app.buttons["topbar.more"].tap()
        XCTAssertTrue(anyElement("tool-reveal.state.content.open", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("content.filter.category.rail", in: app).exists)
        XCTAssertFalse(anyElement("content.filter.category.menu", in: app).exists)
        try saveScreenshot(named: "phase7-fix01-02-content-tools-compact")

        app.buttons["content.filter.category.motion"].tap()
        XCTAssertTrue(anyElement("content.plan.00000000-0000-0000-0000-000000000702", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["content.filter.reset"].exists)
        XCTAssertFalse(anyElement("content.filter.category.menu", in: app).exists)
        try saveScreenshot(named: "phase7-fix01-03-content-filter-active")

        tapStaticText("Motion ưu đãi nệm tháng 8", in: app)
        XCTAssertTrue(anyElement("content.module.linked-indicator", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("content.module.linked-status", in: app).exists)
        XCTAssertTrue(anyElement("content.module.link.passive", in: app).exists)
        try saveScreenshot(named: "phase7-fix01-04-content-linked-detail")
        XCTAssertTrue(anyElement("content.module.editor.passive", in: app).exists)
        XCTAssertTrue(anyElement("content.module.editor.locked-reason", in: app).exists)
        try saveScreenshot(named: "phase7-fix01-05-content-linked-edit-lock")
        app.terminate()

        let incompatible = XCUIApplication()
        launch(incompatible, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "full", phase7Month: "2026-08", phase7Permission: "update-assign-delete")
        incompatible.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.plan-list", in: incompatible).waitForExistence(timeout: 5))
        XCTAssertTrue(incompatible.staticTexts["Không tạo Video Task"].exists)
        try saveScreenshot(named: "phase7-fix01-06-content-incompatible-category")
        incompatible.terminate()

        let error = XCUIApplication()
        launch(error, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "error", phase7Month: "2026-08")
        error.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.load-error", in: error).waitForExistence(timeout: 5))
        XCTAssertFalse(error.staticTexts["Fixture Content Plan lỗi tải."].exists)
        XCTAssertFalse(error.staticTexts["Fixture editor lỗi tải."].exists)
        XCTAssertTrue(error.staticTexts["Không thể tải dữ liệu Content Plan. Vui lòng thử lại."].exists)
        try saveScreenshot(named: "phase7-fix01-07-content-load-error")
        error.terminate()
    }

    func testPhase7ContentPlanBottomScrollSnapshot() throws {
        let bottom = XCUIApplication()
        launch(bottom, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "full", phase7Month: "2026-08", phase7Permission: "update-assign-delete")
        bottom.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.plan-list", in: bottom).waitForExistence(timeout: 5))
        let finalTitle = bottom.staticTexts["Video cuối tháng an toàn scroll"]
        var scrollAttempts = 0
        while (!finalTitle.isHittable || finalTitle.frame.maxY >= bottom.frame.height - 86) && scrollAttempts < 6 {
            bottom.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
            scrollAttempts += 1
        }
        XCTAssertTrue(finalTitle.exists)
        XCTAssertLessThan(finalTitle.frame.maxY, bottom.frame.height - 86)
        try saveScreenshot(named: "phase7-13-content-bottom-scroll-safe")
        XCTAssertTrue(finalTitle.isHittable)
        finalTitle.tap()
        XCTAssertTrue(bottom.staticTexts["Sửa lịch air"].waitForExistence(timeout: 2))
        bottom.terminate()
    }

    func testPhase7Fix01ContentPlanBottomScrollSnapshot() throws {
        let bottom = XCUIApplication()
        launch(bottom, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "full", phase7Month: "2026-08", phase7Permission: "update-assign-delete")
        bottom.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.plan-list", in: bottom).waitForExistence(timeout: 5))
        let finalTitle = bottom.staticTexts["Video cuối tháng an toàn scroll"]
        var scrollAttempts = 0
        while (!finalTitle.isHittable || finalTitle.frame.maxY >= bottom.frame.height - 86) && scrollAttempts < 6 {
            bottom.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
            scrollAttempts += 1
        }
        XCTAssertTrue(finalTitle.exists)
        XCTAssertLessThan(finalTitle.frame.maxY, bottom.frame.height - 86)
        try saveScreenshot(named: "phase7-fix01-08-content-bottom-scroll-safe")
        XCTAssertTrue(finalTitle.isHittable)
        bottom.terminate()
    }

    func testPhase8MembersSnapshots() throws {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "full")
        app.buttons["navbar.members"].tap()
        XCTAssertTrue(anyElement("members.root", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Đoàn Quốc Đạt"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Đoàn Quốc Đạt"].exists)
        XCTAssertTrue(app.staticTexts["Editor · dat"].exists)
        try saveScreenshot(named: "phase8-01-members-main")

        app.buttons["topbar.more"].tap()
        XCTAssertTrue(app.staticTexts["Bộ lọc"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Editor"].exists || app.staticTexts["Editor"].exists)
        try saveScreenshot(named: "phase8-02-members-tools")

        tapStaticText("Đoàn Quốc Đạt", in: app)
        XCTAssertTrue(anyElement("member.module", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Đoàn Quốc Đạt"].exists)
        try saveScreenshot(named: "phase8-03-member-detail")
        XCTAssertTrue(app.textFields["member.form.full-name"].exists)
        try saveScreenshot(named: "phase8-04-member-edit")

        scrollUntilVisible("member.delete", in: app, maxSwipes: 5)
        XCTAssertTrue(app.buttons["member.delete"].waitForExistence(timeout: 2))
        app.buttons["member.delete"].tap()
        XCTAssertTrue(app.staticTexts["Xóa vĩnh viễn tài khoản?"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase8-07-member-destructive-confirm")
        app.terminate()

        let create = XCUIApplication()
        launch(create, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "full")
        create.buttons["navbar.members"].tap()
        XCTAssertTrue(create.staticTexts["Đoàn Quốc Đạt"].waitForExistence(timeout: 5))
        create.buttons["Thêm"].tap()
        XCTAssertTrue(anyElement("member.module", in: create).waitForExistence(timeout: 2))
        XCTAssertTrue(create.staticTexts["Thêm thành viên"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase8-06-member-create-or-invite")
        create.textFields["member.form.full-name"].tap()
        create.textFields["member.form.full-name"].typeText("Lê Demo")
        create.textFields["member.form.display-name"].tap()
        create.textFields["member.form.display-name"].typeText("Demo")
        create.textFields["member.form.email"].tap()
        create.textFields["member.form.email"].typeText("demo@company.com")
        create.secureTextFields["member.form.password"].tap()
        create.secureTextFields["member.form.password"].typeText("temporary123")
        create.buttons["member.save"].tap()
        XCTAssertTrue(anyElement("toast", in: create).waitForExistence(timeout: 3))
        try saveScreenshot(named: "phase8-11-members-restored-toast")
        create.terminate()

        let readonly = XCUIApplication()
        launch(readonly, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "full", phase8Permission: "readonly")
        readonly.buttons["navbar.members"].tap()
        XCTAssertTrue(readonly.staticTexts["Nguyễn Thanh Hải"].waitForExistence(timeout: 5))
        tapStaticText("Nguyễn Thanh Hải", in: readonly)
        XCTAssertTrue(anyElement("member.readonly", in: readonly).waitForExistence(timeout: 2))
        XCTAssertFalse(readonly.textFields["member.form.full-name"].exists)
        XCTAssertFalse(readonly.buttons["member.save"].exists)
        try saveScreenshot(named: "phase8-05-member-readonly")
        readonly.terminate()

        let empty = XCUIApplication()
        launch(empty, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "empty")
        empty.buttons["navbar.members"].tap()
        XCTAssertTrue(empty.staticTexts["Chưa có thành viên"].waitForExistence(timeout: 5))
        try saveScreenshot(named: "phase8-08-members-empty")
        empty.terminate()

        let filterEmpty = XCUIApplication()
        launch(filterEmpty, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "full")
        filterEmpty.buttons["navbar.members"].tap()
        XCTAssertTrue(filterEmpty.staticTexts["Đoàn Quốc Đạt"].waitForExistence(timeout: 5))
        let memberSearchField = filterEmpty.textFields.element(boundBy: 0)
        memberSearchField.tap()
        memberSearchField.typeText("khong-co-ai")
        if filterEmpty.keyboards.buttons["return"].exists {
            filterEmpty.keyboards.buttons["return"].tap()
        }
        XCTAssertTrue(filterEmpty.staticTexts["Không có thành viên phù hợp"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase8-09-members-filter-empty")
        filterEmpty.terminate()

        let error = XCUIApplication()
        launch(error, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "error")
        error.buttons["navbar.members"].tap()
        XCTAssertTrue(error.staticTexts["Không thể tải thành viên"].waitForExistence(timeout: 5))
        XCTAssertFalse(error.staticTexts["Fixture Supabase SQL members error"].exists)
        XCTAssertTrue(error.staticTexts["Không thể tải danh sách thành viên. Vui lòng thử lại."].exists)
        try saveScreenshot(named: "phase8-10-members-load-error")
        error.terminate()
    }

    func testPhase8MembersBottomScrollSnapshot() throws {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "full")
        app.buttons["navbar.members"].tap()
        XCTAssertTrue(app.staticTexts["Đoàn Quốc Đạt"].waitForExistence(timeout: 5))
        let finalTitle = app.staticTexts["Trần Editor Cũ"]
        var attempts = 0
        while (!finalTitle.isHittable || finalTitle.frame.maxY >= app.frame.height - 86) && attempts < 6 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
            attempts += 1
        }
        XCTAssertTrue(finalTitle.exists)
        XCTAssertLessThan(finalTitle.frame.maxY, app.frame.height - 86)
        try saveScreenshot(named: "phase8-12-members-bottom-scroll-safe")
        app.terminate()
    }

    func testPhase8Fix01MembersClosureSnapshots() throws {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "full")
        app.buttons["navbar.members"].tap()
        XCTAssertTrue(app.staticTexts["Đoàn Quốc Đạt"].waitForExistence(timeout: 5))
        let rootStatsHeading = app.staticTexts["Vai trò"]
        var rootAttempts = 0
        while (!rootStatsHeading.exists || !rootStatsHeading.isHittable) && rootAttempts < 5 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
            rootAttempts += 1
        }
        XCTAssertTrue(rootStatsHeading.exists)
        XCTAssertTrue(rootStatsHeading.isHittable)
        XCTAssertTrue(app.staticTexts["Vai trò"].exists)
        XCTAssertFalse(app.staticTexts["PHÒNG BAN"].exists)
        try saveScreenshot(named: "phase8-fix01-01-members-main-semantic")

        XCTAssertTrue(app.staticTexts["Trần Editor Cũ"].exists)
        tapStaticText("Trần Editor Cũ", in: app)
        XCTAssertTrue(anyElement("member.module", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["member.form.full-name"].exists)
        try saveScreenshot(named: "phase8-fix01-04-member-edit")
        let safePermissionSummary = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Quyền sử dụng được áp dụng theo chế độ đã chọn")).firstMatch
        var summaryAttempts = 0
        while (!safePermissionSummary.exists || !safePermissionSummary.isHittable) && summaryAttempts < 5 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
            summaryAttempts += 1
        }
        XCTAssertTrue(safePermissionSummary.exists)
        XCTAssertTrue(safePermissionSummary.isHittable)
        XCTAssertFalse(app.staticTexts["Theo vai trò · users_manage vẫn khóa admin-only theo backend."].exists)
        try saveScreenshot(named: "phase8-fix01-02-members-copy-sanitized")

        scrollUntilVisible("member.delete", in: app, maxSwipes: 5)
        XCTAssertTrue(app.buttons["member.delete"].waitForExistence(timeout: 2))
        app.buttons["member.delete"].tap()
        XCTAssertTrue(app.staticTexts["Xóa vĩnh viễn tài khoản?"].waitForExistence(timeout: 2))
        let productionDeleteCopy = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Tài khoản đăng nhập sẽ bị xóa vĩnh viễn")).firstMatch
        XCTAssertTrue(productionDeleteCopy.exists)
        XCTAssertFalse(app.staticTexts["Tài khoản và dữ liệu thử nghiệm liên quan sẽ bị xóa. Thao tác này không thể hoàn tác."].exists)
        try saveScreenshot(named: "phase8-fix01-05-member-delete-confirm-production-copy")
        app.terminate()

        let detail = XCUIApplication()
        launch(detail, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "full", phase8Permission: "readonly")
        detail.buttons["navbar.members"].tap()
        XCTAssertTrue(detail.staticTexts["Nguyễn Thanh Hải"].waitForExistence(timeout: 5))
        tapStaticText("Nguyễn Thanh Hải", in: detail)
        XCTAssertTrue(anyElement("member.readonly", in: detail).waitForExistence(timeout: 2))
        XCTAssertTrue(detail.staticTexts["Chi tiết thành viên"].exists)
        XCTAssertFalse(detail.textFields["member.form.full-name"].exists)
        XCTAssertFalse(detail.buttons["member.save"].exists)
        try saveScreenshot(named: "phase8-fix01-03-member-detail")
        detail.swipeUp()
        Thread.sleep(forTimeInterval: 0.25)
        XCTAssertFalse(detail.buttons["member.delete"].exists)
        try saveScreenshot(named: "phase8-fix01-06-member-readonly-regression")
        detail.terminate()

        let bottom = XCUIApplication()
        launch(bottom, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "full")
        bottom.buttons["navbar.members"].tap()
        XCTAssertTrue(bottom.staticTexts["Đoàn Quốc Đạt"].waitForExistence(timeout: 5))
        let statsHeading = bottom.staticTexts["Vai trò"]
        let statsCreator = bottom.staticTexts["Creator"]
        let navTop = bottom.buttons["navbar.members"].frame.minY
        var attempts = 0
        while (!statsCreator.exists || statsCreator.frame.maxY >= navTop - 12) && attempts < 8 {
            bottom.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
            attempts += 1
        }
        XCTAssertTrue(statsHeading.exists)
        XCTAssertLessThan(statsHeading.frame.maxY, navTop - 12)
        XCTAssertTrue(bottom.staticTexts["Admin"].exists)
        XCTAssertTrue(bottom.staticTexts["Manager"].exists)
        XCTAssertTrue(statsCreator.exists)
        XCTAssertLessThan(statsCreator.frame.maxY, navTop - 12)
        try saveScreenshot(named: "phase8-fix01-07-members-bottom-scroll-safe")
        bottom.terminate()

        let create = XCUIApplication()
        launch(create, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "full")
        create.buttons["navbar.members"].tap()
        XCTAssertTrue(create.staticTexts["Đoàn Quốc Đạt"].waitForExistence(timeout: 5))
        create.buttons["Thêm"].tap()
        XCTAssertTrue(create.staticTexts["Thêm thành viên"].waitForExistence(timeout: 2))
        create.textFields["member.form.full-name"].tap()
        create.textFields["member.form.full-name"].typeText("Lê Demo")
        create.textFields["member.form.display-name"].tap()
        create.textFields["member.form.display-name"].typeText("Demo")
        create.textFields["member.form.email"].tap()
        create.textFields["member.form.email"].typeText("demo@company.com")
        create.secureTextFields["member.form.password"].tap()
        create.secureTextFields["member.form.password"].typeText("temporary123")
        create.buttons["member.save"].tap()
        XCTAssertTrue(anyElement("toast", in: create).waitForExistence(timeout: 3))
        XCTAssertTrue(create.buttons["navbar.members"].exists)
        try saveScreenshot(named: "phase8-fix01-08-members-restored-toast")
        create.terminate()
    }

    func testPhase8Fix02MembersModuleVisualClosureSnapshots() throws {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "full")
        app.buttons["navbar.members"].tap()
        XCTAssertTrue(app.staticTexts["Đoàn Quốc Đạt"].waitForExistence(timeout: 5))
        tapStaticText("Trần Editor Cũ", in: app)
        XCTAssertTrue(anyElement("member.module", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["navbar.members"].exists)

        let actionBars = app.descendants(matching: .any).matching(identifier: "member.action-bar")
        XCTAssertEqual(actionBars.count, 1)
        let cancel = app.buttons["member.cancel"]
        let save = app.buttons["member.save"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 2))
        XCTAssertTrue(save.waitForExistence(timeout: 2))
        XCTAssertEqual(cancel.label, "Hủy")
        XCTAssertTrue(save.label.localizedCaseInsensitiveContains("Lưu thay đổi"))
        XCTAssertGreaterThanOrEqual(cancel.frame.width, 120)
        XCTAssertGreaterThanOrEqual(save.frame.width, 150)
        XCTAssertLessThan(save.frame.maxY, app.frame.height - 14)
        try saveScreenshot(named: "phase8-fix02-01-member-edit-bottom-actions")

        let fullName = app.textFields["member.form.full-name"]
        XCTAssertTrue(fullName.exists)
        let originalFullName = String(describing: fullName.value ?? "")
        let delete = app.buttons["member.delete"]
        var deleteAttempts = 0
        while (!delete.exists || !delete.isHittable) && deleteAttempts < 8 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
            deleteAttempts += 1
        }
        XCTAssertTrue(delete.exists)
        XCTAssertTrue(delete.isHittable)
        delete.tap()

        XCTAssertTrue(anyElement("member.delete.confirm", in: app).waitForExistence(timeout: 2))
        let deleteTitle = app.staticTexts["Xóa vĩnh viễn tài khoản?"]
        XCTAssertTrue(deleteTitle.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(deleteTitle.frame.minY, app.buttons["module.back"].frame.maxY)
        let productionDeleteCopy = anyElement("member.delete.copy", in: app)
        XCTAssertTrue(productionDeleteCopy.label.localizedCaseInsensitiveContains("Tài khoản đăng nhập sẽ bị xóa vĩnh viễn"))
        XCTAssertLessThan(app.buttons["member.delete.cancel"].frame.maxY, app.frame.height - 18)
        XCTAssertFalse(app.staticTexts["Tài khoản và dữ liệu thử nghiệm liên quan sẽ bị xóa. Thao tác này không thể hoàn tác."].exists)
        XCTAssertFalse(app.staticTexts["Theo vai trò · users_manage vẫn khóa admin-only theo backend."].exists)
        XCTAssertTrue(app.textFields["member.delete.confirm-email"].exists)
        XCTAssertFalse(save.isHittable)
        try saveScreenshot(named: "phase8-fix02-02-member-delete-confirm-isolated")

        app.buttons["member.delete.cancel"].tap()
        XCTAssertFalse(anyElement("member.delete.confirm", in: app).waitForExistence(timeout: 1))
        XCTAssertTrue(anyElement("member.module", in: app).exists)
        XCTAssertTrue(app.buttons["member.save"].exists)
        XCTAssertEqual(String(describing: app.textFields["member.form.full-name"].value ?? ""), originalFullName)
        try saveScreenshot(named: "phase8-fix02-03-member-delete-cancel-restores-edit")
        app.terminate()

        let readonly = XCUIApplication()
        launch(readonly, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "full", phase8Permission: "readonly")
        readonly.buttons["navbar.members"].tap()
        XCTAssertTrue(readonly.staticTexts["Nguyễn Thanh Hải"].waitForExistence(timeout: 5))
        tapStaticText("Nguyễn Thanh Hải", in: readonly)
        XCTAssertTrue(anyElement("member.readonly", in: readonly).waitForExistence(timeout: 2))
        XCTAssertFalse(readonly.descendants(matching: .any).matching(identifier: "member.action-bar").element.exists)
        XCTAssertFalse(readonly.buttons["member.save"].exists)
        XCTAssertFalse(readonly.buttons["member.cancel"].exists)
        try saveScreenshot(named: "phase8-fix02-04-member-readonly-no-actions")
        readonly.terminate()

        let bottom = XCUIApplication()
        launch(bottom, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase8Fixture: "full")
        bottom.buttons["navbar.members"].tap()
        XCTAssertTrue(bottom.staticTexts["Đoàn Quốc Đạt"].waitForExistence(timeout: 5))
        let statsHeading = bottom.staticTexts["Vai trò"]
        let statsCreator = bottom.staticTexts["Creator"]
        let navTop = bottom.buttons["navbar.members"].frame.minY
        var attempts = 0
        while (!statsCreator.exists || statsCreator.frame.maxY >= navTop - 12) && attempts < 8 {
            bottom.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
            attempts += 1
        }
        XCTAssertTrue(statsHeading.exists)
        XCTAssertLessThan(statsHeading.frame.maxY, navTop - 12)
        XCTAssertTrue(statsCreator.exists)
        XCTAssertLessThan(statsCreator.frame.maxY, navTop - 12)
        try saveScreenshot(named: "phase8-fix02-05-members-bottom-scroll-safe")
        bottom.terminate()
    }

    func testPhase9NotificationsSnapshots() throws {
        let bellUnread = XCUIApplication()
        launch(bellUnread, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase9Fixture: "mixed")
        XCTAssertTrue(bellUnread.buttons["topbar.notifications"].waitForExistence(timeout: 5))
        XCTAssertEqual(bellUnread.buttons["topbar.notifications"].value as? String, "Có thông báo chưa đọc")
        try saveScreenshot(named: "phase9-10-bell-unread-indicator")
        bellUnread.terminate()

        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase5Fixture: "full", phase5Date: "2026-08-17", phase6Fixture: "full", phase6Month: "2026-08", phase7Fixture: "full", phase7Month: "2026-08", phase8Fixture: "full", phase9Fixture: "mixed")
        XCTAssertTrue(app.buttons["topbar.notifications"].waitForExistence(timeout: 5))
        app.buttons["topbar.notifications"].tap()
        XCTAssertTrue(anyElement("secondary.notifications", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("notifications.root", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["navbar.video"].waitForExistence(timeout: 1))
        XCTAssertTrue(anyElement("notifications.list", in: app).exists)
        XCTAssertTrue(app.staticTexts["Video Task đã hoàn thành"].exists)
        XCTAssertTrue(app.staticTexts["Cập nhật hệ thống"].exists)
        try saveScreenshot(named: "phase9-01-notifications-main")
        try saveScreenshot(named: "phase9-02-notifications-unread")

        anyElement("notification.row.00000000-0000-0000-0000-000000000904", in: app).tap()
        XCTAssertTrue(anyElement("toast", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase9-03-notification-opened-read")

        XCTAssertTrue(app.buttons["notifications.mark-all"].waitForExistence(timeout: 2))
        app.buttons["notifications.mark-all"].tap()
        XCTAssertTrue(app.staticTexts["Đã đọc hết"].waitForExistence(timeout: 3))
        try saveScreenshot(named: "phase9-04-notifications-mark-all-read")

        scrollUntilVisible("notification.row.00000000-0000-0000-0000-000000000905", in: app)
        XCTAssertTrue(anyElement("notification.row.00000000-0000-0000-0000-000000000905", in: app).exists)
        try saveScreenshot(named: "phase9-09-notifications-bottom-scroll-safe")
        app.terminate()

        let deeplink = XCUIApplication()
        launch(deeplink, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase6Fixture: "full", phase6Month: "2026-08", phase9Fixture: "mixed")
        XCTAssertTrue(deeplink.buttons["topbar.notifications"].waitForExistence(timeout: 5))
        deeplink.buttons["topbar.notifications"].tap()
        XCTAssertTrue(anyElement("notifications.root", in: deeplink).waitForExistence(timeout: 5))
        anyElement("notification.row.00000000-0000-0000-0000-000000000901", in: deeplink).tap()
        XCTAssertTrue(anyElement("video.module", in: deeplink).waitForExistence(timeout: 3))
        XCTAssertFalse(deeplink.buttons["navbar.video"].exists)
        try saveScreenshot(named: "phase9-05-notification-deeplink")
        deeplink.terminate()

        let unavailable = XCUIApplication()
        launch(unavailable, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase7Fixture: "full", phase7Month: "2026-08", phase9Fixture: "unavailable")
        XCTAssertTrue(unavailable.buttons["topbar.notifications"].waitForExistence(timeout: 5))
        unavailable.buttons["topbar.notifications"].tap()
        XCTAssertTrue(anyElement("notifications.root", in: unavailable).waitForExistence(timeout: 5))
        anyElement("notification.row.00000000-0000-0000-0000-000000000905", in: unavailable).tap()
        XCTAssertTrue(anyElement("toast", in: unavailable).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase9-06-notification-destination-unavailable")
        unavailable.terminate()

        let empty = XCUIApplication()
        launch(empty, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase9Fixture: "empty")
        XCTAssertTrue(empty.buttons["topbar.notifications"].waitForExistence(timeout: 5))
        empty.buttons["topbar.notifications"].tap()
        XCTAssertTrue(anyElement("notifications.empty", in: empty).waitForExistence(timeout: 5))
        XCTAssertTrue(empty.staticTexts["Chưa có thông báo"].exists)
        try saveScreenshot(named: "phase9-07-notifications-empty")
        empty.terminate()

        let error = XCUIApplication()
        launch(error, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase9Fixture: "error")
        XCTAssertTrue(error.buttons["topbar.notifications"].waitForExistence(timeout: 5))
        error.buttons["topbar.notifications"].tap()
        XCTAssertTrue(anyElement("notifications.load-error", in: error).waitForExistence(timeout: 5))
        XCTAssertTrue(error.staticTexts["Không thể tải thông báo"].exists)
        XCTAssertTrue(error.buttons["Thử lại"].exists)
        try saveScreenshot(named: "phase9-08-notifications-load-error")
        error.terminate()

        let zero = XCUIApplication()
        launch(zero, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase9Fixture: "zero-unread")
        XCTAssertTrue(zero.buttons["topbar.notifications"].waitForExistence(timeout: 5))
        XCTAssertEqual(zero.buttons["topbar.notifications"].value as? String, "Không có thông báo chưa đọc")
        try saveScreenshot(named: "phase9-11-bell-zero-unread")
        zero.terminate()
    }

    func testPhase10ProfileAccountSnapshots() throws {
        let app = XCUIApplication()
        launch(app, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase10Fixture: "normal")

        openProfileFromVideo(in: app)
        XCTAssertTrue(app.staticTexts["Đạt Đoàn"].exists)
        XCTAssertTrue(app.staticTexts["dat@creativehub.local"].exists)
        assertUnsupportedProfilePreferencesAbsent(in: app)
        try saveScreenshot(named: "phase10-01-profile-main")
        try saveScreenshot(named: "phase10-fix01-01-profile-main-clean")

        app.buttons["profile.edit"].tap()
        XCTAssertTrue(anyElement("profile.edit.sheet", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["profile.form.full-name"].exists)
        XCTAssertTrue(anyElement("profile.form.role", in: app).exists)
        XCTAssertFalse(app.textFields["profile.form.role"].exists)
        try saveScreenshot(named: "phase10-02-profile-edit")
        try saveScreenshot(named: "phase10-fix01-02-profile-edit-clean")

        app.swipeUp()
        XCTAssertTrue(anyElement("profile.action-bar", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["profile.edit.cancel"].exists)
        XCTAssertTrue(app.buttons["profile.edit.save"].exists)
        try saveScreenshot(named: "phase10-03-profile-edit-bottom-actions")
        try saveScreenshot(named: "phase10-fix01-03-profile-edit-bottom-actions")

        app.buttons["profile.edit.cancel"].tap()
        XCTAssertTrue(anyElement("profile.root", in: app).waitForExistence(timeout: 2))
        app.buttons["profile.edit"].tap()
        let displayName = app.textFields["profile.form.display-name"]
        replaceText(in: displayName, with: "Đạt Phase 10", app: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        app.buttons["profile.edit.save"].tap()
        XCTAssertTrue(anyElement("toast", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase10-04-profile-save-success")
        try saveScreenshot(named: "phase10-fix01-04-profile-save-replacement")
        XCTAssertTrue(app.staticTexts["Đạt Phase 10"].exists)
        XCTAssertFalse(app.staticTexts["Đạt ĐoànĐạt Phase 10"].exists)
        anyElement("toast", in: app).tap()
        Thread.sleep(forTimeInterval: 0.3)

        app.buttons["profile.edit"].tap()
        let reopenedDisplayName = app.textFields["profile.form.display-name"]
        XCTAssertTrue(reopenedDisplayName.waitForExistence(timeout: 2))
        XCTAssertEqual(reopenedDisplayName.value as? String, "Đạt Phase 10")
        app.buttons["profile.edit.cancel"].tap()
        app.terminate()

        let reset = XCUIApplication()
        launch(reset, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase10Fixture: "normal")
        openProfileFromVideo(in: reset)
        XCTAssertTrue(reset.staticTexts["Đạt Đoàn"].exists)
        XCTAssertFalse(reset.staticTexts["Đạt Phase 10"].exists)
        assertUnsupportedProfilePreferencesAbsent(in: reset)

        reset.buttons["profile.password"].tap()
        XCTAssertTrue(anyElement("profile.password.sheet", in: reset).waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("profile.password.current", in: reset).exists)
        try saveScreenshot(named: "phase10-06-profile-password")
        try saveScreenshot(named: "phase10-fix01-07-profile-password-regression")
        reset.buttons["profile.password.cancel"].tap()

        reset.buttons["profileLogoutButton"].tap()
        XCTAssertTrue(anyElement("logoutConfirmation", in: reset).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase10-09-profile-logout")
        try saveScreenshot(named: "phase10-fix01-08-profile-logout-regression")
        reset.buttons["logoutCancelButton"].tap()

        reset.swipeUp()
        XCTAssertTrue(anyElement("profile.bottom", in: reset).waitForExistence(timeout: 2))
        assertUnsupportedProfilePreferencesAbsent(in: reset)
        try saveScreenshot(named: "phase10-10-profile-bottom-scroll-safe")
        try saveScreenshot(named: "phase10-fix01-09-profile-bottom-scroll-safe")

        reset.buttons["topbar.back"].tap()
        XCTAssertTrue(reset.buttons["navbar.video"].waitForExistence(timeout: 2))
        XCTAssertTrue(reset.staticTexts["Video tháng"].exists)
        try saveScreenshot(named: "phase10-11-profile-back-restores-shell")
        try saveScreenshot(named: "phase10-fix01-10-profile-back-restores-shell")
        reset.terminate()

        let avatar = XCUIApplication()
        launch(avatar, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase10Fixture: "avatar")
        openProfileFromVideo(in: avatar)
        XCTAssertTrue(anyElement("profile.avatar.remote.marker", in: avatar).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase10-05-profile-avatar")
        try saveScreenshot(named: "phase10-fix01-05-profile-avatar-actual-image")
        avatar.buttons["profile.edit"].tap()
        XCTAssertTrue(avatar.buttons["profile.avatar.pick"].waitForExistence(timeout: 2))
        XCTAssertTrue(avatar.buttons["profile.avatar.remove"].exists)
        avatar.buttons["profile.avatar.remove"].tap()
        avatar.buttons["profile.edit.save"].tap()
        XCTAssertTrue(anyElement("toast", in: avatar).waitForExistence(timeout: 2))
        anyElement("toast", in: avatar).tap()
        XCTAssertTrue(anyElement("profile.avatar.initials.marker", in: avatar).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase10-fix01-06-profile-avatar-remove")
        avatar.terminate()

        let error = XCUIApplication()
        launch(error, phase2State: "authenticated-shell", phase4Fixture: "visual", phase4Month: "2026-08", phase10Fixture: "load-error")
        XCTAssertTrue(error.buttons["topbar.profile"].waitForExistence(timeout: 5))
        error.buttons["topbar.profile"].tap()
        XCTAssertTrue(anyElement("profile.load-error", in: error).waitForExistence(timeout: 5))
        XCTAssertTrue(error.staticTexts["Không thể tải hồ sơ"].exists)
        XCTAssertTrue(error.buttons["Thử lại"].exists)
        try saveScreenshot(named: "phase10-08-profile-load-error")
        error.terminate()
    }

    func testPhase11UnifiedTimeNavigationScreenshots() throws {
        let app = XCUIApplication()
        launch(
            app,
            phase2State: "authenticated-shell",
            phase4Fixture: "visual",
            phase4Month: "2026-08",
            phase5Fixture: "full",
            phase5Date: "2026-08-18",
            phase6Fixture: "full",
            phase6Month: "2026-08",
            phase7Fixture: "full",
            phase7Month: "2026-08",
            phase11Scope: nil,
            phase11Date: "2026-08-18"
        )

        XCTAssertTrue(app.buttons["navbar.video"].waitForExistence(timeout: 5))
        app.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timeScopeButton"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["timeScopeButton"].value as? String, "Tuần")
        XCTAssertTrue(app.buttons["video.week.2026-08-18"].waitForExistence(timeout: 2))
        XCTAssertLessThan(anyElement("video.month.label", in: app).frame.minY - app.staticTexts["topbar.title"].frame.maxY, 56)
        try saveScreenshot(named: "phase11-01-video-header-gap-fixed")
        try saveScreenshot(named: "phase11-02-video-current-week")
        try saveScreenshot(named: "phase11-12-current-day-today-indicator")

        app.buttons["video.week.2026-08-18"].tap()
        XCTAssertTrue(anyElement("video.task.00000000-0000-0000-0000-000000000607", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(anyElement("video.task.00000000-0000-0000-0000-000000000608", in: app).exists)
        try saveScreenshot(named: "phase11-03-video-exact-day")

        app.buttons["video.week.2026-08-19"].tap()
        XCTAssertTrue(anyElement("video.month-empty", in: app).waitForExistence(timeout: 2))
        selectTimeScope("Tuần", prefix: "video", in: app)
        app.buttons["video.month.next"].tap()
        XCTAssertTrue(anyElement("video.task.00000000-0000-0000-0000-000000000608", in: app).waitForExistence(timeout: 2))
        app.buttons["video.month.next"].tap()
        XCTAssertTrue(anyElement("video.month-empty", in: app).waitForExistence(timeout: 2))
        app.buttons["video.month.prev"].tap()
        app.buttons["video.month.prev"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: app).waitForExistence(timeout: 2))

        selectTimeScope("Tháng", prefix: "video", in: app)
        XCTAssertTrue(anyElement("video.task.00000000-0000-0000-0000-000000000608", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase11-04-video-full-month")

        app.buttons["navbar.calendar"].tap()
        XCTAssertTrue(anyElement("calendar.agenda-list", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timeScopeButton"].exists)
        try saveScreenshot(named: "phase11-05-calendar-current-week")

        app.buttons["calendar.week.2026-08-18"].tap()
        XCTAssertTrue(anyElement("calendar.agenda.00000000-0000-0000-0000-000000000004", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(anyElement("calendar.agenda.00000000-0000-0000-0000-000000000005", in: app).exists)
        try saveScreenshot(named: "phase11-06-calendar-exact-day")

        selectTimeScope("Tháng", prefix: "calendar", in: app)
        XCTAssertTrue(anyElement("calendar.agenda.00000000-0000-0000-0000-000000000005", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase11-07-calendar-full-month")

        app.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.plan-list", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timeScopeButton"].exists)
        try saveScreenshot(named: "phase11-08-content-current-week")

        app.buttons["content.week.2026-08-20"].tap()
        XCTAssertTrue(anyElement("content.plan.00000000-0000-0000-0000-000000000708", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(anyElement("content.plan.00000000-0000-0000-0000-000000000707", in: app).exists)
        try saveScreenshot(named: "phase11-09-content-exact-day")

        selectTimeScope("Tháng", prefix: "content", in: app)
        XCTAssertTrue(anyElement("content.plan.00000000-0000-0000-0000-000000000707", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase11-10-content-full-month")

        let finalTitle = app.staticTexts["Video cuối tháng an toàn scroll"]
        var scrollAttempts = 0
        while (!finalTitle.isHittable || finalTitle.frame.maxY >= app.frame.height - 86) && scrollAttempts < 6 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
            scrollAttempts += 1
        }
        XCTAssertTrue(finalTitle.isHittable)
        try saveScreenshot(named: "phase11-13-bottom-scroll-safety")
        app.terminate()

        let boundary = XCUIApplication()
        launch(
            boundary,
            phase2State: "authenticated-shell",
            phase4Fixture: "visual",
            phase4Month: "2026-08",
            phase6Fixture: "full",
            phase6Month: "2026-08",
            phase11Scope: nil,
            phase11Date: "2026-08-31"
        )
        XCTAssertTrue(boundary.buttons["navbar.video"].waitForExistence(timeout: 5))
        boundary.buttons["navbar.video"].tap()
        XCTAssertTrue(boundary.buttons["video.week.2026-08-31"].waitForExistence(timeout: 5))
        XCTAssertTrue(boundary.buttons["video.week.2026-09-01"].exists)
        try saveScreenshot(named: "phase11-11-week-crossing-month-boundary")
        boundary.terminate()
    }

    func testPhase11Fix01CompactNavigatorPreferenceSnapshots() throws {
        let suite = "CreativeHubUITests.phase11fix01.\(UUID().uuidString)"
        let userA = "11111111-1111-1111-1111-111111111111"
        let userB = "22222222-2222-2222-2222-222222222222"
        let app = XCUIApplication()
        launch(
            app,
            phase2State: "authenticated-shell",
            phase4Fixture: "visual",
            phase4Month: "2026-08",
            phase5Fixture: "full",
            phase5Date: "2026-08-22",
            phase6Fixture: "full",
            phase6Month: "2026-08",
            phase7Fixture: "full",
            phase7Month: "2026-08",
            phase11Scope: nil,
            phase11Date: "2026-08-22",
            phase11ProfileID: userA,
            timeScopeDefaultsSuite: suite
        )

        XCTAssertTrue(app.buttons["navbar.video"].waitForExistence(timeout: 5))
        app.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["timeScopeButton"].value as? String, "Tuần")
        XCTAssertFalse(app.buttons["video.scope.day"].exists)
        XCTAssertLessThan(anyElement("video.month.label", in: app).frame.minY - app.staticTexts["topbar.title"].frame.maxY, 52)
        try saveScreenshot(named: "phase11-fix01-01-video-compact-week")
        try saveScreenshot(named: "phase11-fix01-05-video-no-header-gap")

        app.buttons["timeScopeButton"].tap()
        let dayOption = app.buttons["timeScopeDay"]
        XCTAssertTrue(dayOption.waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase11-fix01-10-time-filter-menu")
        dayOption.tap()
        app.buttons["video.week.2026-08-18"].tap()
        XCTAssertTrue(anyElement("video.task.00000000-0000-0000-0000-000000000607", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(anyElement("video.task.00000000-0000-0000-0000-000000000608", in: app).exists)
        try saveScreenshot(named: "phase11-fix01-02-video-day")

        selectTimeScope("Tuần", prefix: "video", in: app)
        XCTAssertTrue(anyElement("video.task-list", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(anyElement("video.task.00000000-0000-0000-0000-000000000608", in: app).exists)
        try saveScreenshot(named: "phase11-fix01-03-video-week")

        selectTimeScope("Tháng", prefix: "video", in: app)
        XCTAssertTrue(anyElement("video.task.00000000-0000-0000-0000-000000000608", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase11-fix01-04-video-month")

        app.buttons["navbar.calendar"].tap()
        XCTAssertTrue(anyElement("calendar.agenda-list", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["timeScopeButton"].value as? String, "Tuần")
        try saveScreenshot(named: "phase11-fix01-06-calendar-compact-week")
        app.buttons["calendar.week.2026-08-18"].tap()
        XCTAssertTrue(anyElement("calendar.agenda.00000000-0000-0000-0000-000000000004", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(anyElement("calendar.agenda.00000000-0000-0000-0000-000000000005", in: app).exists)
        try saveScreenshot(named: "phase11-fix01-07-calendar-day")

        app.buttons["navbar.content"].tap()
        XCTAssertTrue(anyElement("content.plan-list", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["timeScopeButton"].value as? String, "Tuần")
        try saveScreenshot(named: "phase11-fix01-08-content-compact-week")
        app.buttons["content.week.2026-08-20"].tap()
        XCTAssertTrue(anyElement("content.plan.00000000-0000-0000-0000-000000000708", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(anyElement("content.plan.00000000-0000-0000-0000-000000000707", in: app).exists)
        try saveScreenshot(named: "phase11-fix01-09-content-day")

        app.buttons["navbar.video"].tap()
        XCTAssertEqual(app.buttons["timeScopeButton"].value as? String, "Tháng")
        try saveScreenshot(named: "phase11-fix01-11-persisted-mode-restored")

        let finalTitle = app.staticTexts["Video cuối tháng an toàn scroll"]
        let navTop = app.buttons["navbar.video"].frame.minY
        for _ in 0..<10 {
            if finalTitle.exists && finalTitle.frame.maxY < navTop - 12 {
                break
            }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertTrue(app.buttons["navbar.video"].isHittable)
        try saveScreenshot(named: "phase11-fix01-12-bottom-scroll-safe")
        app.terminate()

        let userBApp = XCUIApplication()
        launch(
            userBApp,
            phase2State: "authenticated-shell",
            phase4Fixture: "visual",
            phase4Month: "2026-08",
            phase6Fixture: "full",
            phase6Month: "2026-08",
            phase11Scope: nil,
            phase11Date: "2026-08-22",
            phase11ProfileID: userB,
            timeScopeDefaultsSuite: suite
        )
        XCTAssertTrue(userBApp.buttons["navbar.video"].waitForExistence(timeout: 5))
        userBApp.buttons["navbar.video"].tap()
        XCTAssertEqual(userBApp.buttons["timeScopeButton"].value as? String, "Tuần")
        userBApp.terminate()
    }

    func testPhase11Fix02LogoutResetAndCustomTimeScopePopoverSnapshots() throws {
        let app = XCUIApplication()
        launch(
            app,
            phase2State: "authenticated-shell",
            phase4Fixture: "visual",
            phase4Month: "2026-08",
            phase5Fixture: "full",
            phase5Date: "2026-08-22",
            phase6Fixture: "full",
            phase6Month: "2026-08",
            phase7Fixture: "full",
            phase7Month: "2026-08",
            phase10Fixture: "normal",
            phase11Scope: nil,
            phase11Date: "2026-08-22",
            phase11Fix02LoginFixture: true
        )

        openProfileFromVideo(in: app)
        app.buttons["profileLogoutButton"].tap()
        XCTAssertTrue(anyElement("logoutConfirmation", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase11-fix02-01-profile-logout-centered")
        app.buttons["logoutCancelButton"].tap()

        app.swipeUp()
        XCTAssertTrue(anyElement("profile.bottom", in: app).waitForExistence(timeout: 2))
        app.buttons["profileLogoutButton"].tap()
        XCTAssertTrue(anyElement("logoutConfirmation", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase11-fix02-02-profile-logout-scrolled-centered")

        app.buttons["logoutConfirmButton"].tap()
        XCTAssertTrue(anyElement("login-card", in: app).waitForExistence(timeout: 5))
        try saveScreenshot(named: "phase11-fix02-03-login-after-logout")

        let email = app.textFields["login-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 2))
        email.tap()
        email.typeText("qa@example.test")

        let password = app.secureTextFields["login-password"]
        XCTAssertTrue(password.waitForExistence(timeout: 2))
        password.tap()
        password.typeText("password123")
        app.buttons["login-submit"].tap()

        XCTAssertTrue(anyElement("overview.dashboard", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["navbar.overview"].waitForExistence(timeout: 2))
        XCTAssertFalse(anyElement("secondary.profile", in: app).exists)
        XCTAssertFalse(anyElement("profile.root", in: app).exists)
        try saveScreenshot(named: "phase11-fix02-04-post-login-overview")

        app.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: app).waitForExistence(timeout: 5))
        selectTimeScope("Ngày", prefix: "video", in: app)
        app.buttons["timeScopeButton"].tap()
        XCTAssertTrue(anyElement("timeScopePopover", in: app).waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["timeScopeButton"].value as? String, "Ngày")
        try saveScreenshot(named: "phase11-fix02-05-time-scope-popover-day")

        app.buttons["timeScopeWeek"].tap()
        app.buttons["timeScopeButton"].tap()
        XCTAssertTrue(anyElement("timeScopePopover", in: app).waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["timeScopeButton"].value as? String, "Tuần")
        try saveScreenshot(named: "phase11-fix02-06-time-scope-popover-week")

        app.buttons["timeScopeMonth"].tap()
        app.buttons["timeScopeButton"].tap()
        XCTAssertTrue(anyElement("timeScopePopover", in: app).waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["timeScopeButton"].value as? String, "Tháng")
        try saveScreenshot(named: "phase11-fix02-07-time-scope-popover-month")

        anyElement("video.month.label", in: app).tap()
        XCTAssertFalse(anyElement("timeScopePopover", in: app).waitForExistence(timeout: 1))
        try saveScreenshot(named: "phase11-fix02-08-time-scope-dismiss")
        app.terminate()
    }

    func testPhase11Fix03RealDeviceUXSnapshots() throws {
        let loading = XCUIApplication()
        launch(loading, phase2State: "loading")
        XCTAssertTrue(anyElement("session-bootstrap-logo", in: loading).waitForExistence(timeout: 5))
        XCTAssertFalse(loading.staticTexts["Đang kiểm tra phiên"].exists)
        try saveScreenshot(named: "phase11-fix03-01-session-bootstrap-logo")
        loading.terminate()

        let app = XCUIApplication()
        launch(
            app,
            phase2State: "authenticated-shell",
            phase4Fixture: "visual",
            phase4Month: "2026-08",
            phase5Fixture: "full",
            phase5Date: "2026-08-21",
            phase6Fixture: "full",
            phase6Month: "2026-08",
            phase7Fixture: "full",
            phase7Month: "2026-08",
            phase9Fixture: "mixed",
            phase10Fixture: "normal",
            phase11Scope: nil,
            phase11Date: "2026-08-21",
            phase11Fix02LoginFixture: true,
            phase11Fix03SignOutDelayMS: 800
        )

        openProfileFromVideo(in: app)
        app.buttons["profileLogoutButton"].tap()
        XCTAssertTrue(anyElement("logoutConfirmation", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase11-fix03-02-logout-dialog")

        app.buttons["logoutConfirmButton"].tap()
        XCTAssertTrue(anyElement("logoutProcessingIndicator", in: app).waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase11-fix03-03-logout-processing")
        XCTAssertTrue(anyElement("login-card", in: app).waitForExistence(timeout: 5))

        app.textFields["login-email"].tap()
        app.textFields["login-email"].typeText("qa@example.test")
        app.secureTextFields["login-password"].tap()
        app.secureTextFields["login-password"].typeText("password123")
        app.buttons["login-submit"].tap()
        XCTAssertTrue(anyElement("overview.dashboard", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["navbar.overview"].exists)
        XCTAssertFalse(anyElement("secondary.profile", in: app).exists)
        try saveScreenshot(named: "phase11-fix03-04-logout-login-overview")

        app.buttons["navbar.video"].tap()
        XCTAssertTrue(anyElement("video.task-list", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["timeScopeButton"].value as? String, "Tuần")
        XCTAssertTrue(app.buttons["video.week.2026-08-21"].waitForExistence(timeout: 2))
        try saveScreenshot(named: "phase11-fix03-05-current-week-today")

        app.buttons["video.month.next"].tap()
        XCTAssertTrue(app.buttons["video.week.2026-08-24"].waitForExistence(timeout: 3))
        try saveScreenshot(named: "phase11-fix03-06-next-week-monday")

        app.buttons["video.month.prev"].tap()
        XCTAssertTrue(app.buttons["video.week.2026-08-17"].waitForExistence(timeout: 3))
        try saveScreenshot(named: "phase11-fix03-07-previous-week-monday")

        app.swipeDown()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(anyElement("video.root", in: app).exists)
        XCTAssertTrue(app.buttons["navbar.video"].exists)
        try saveScreenshot(named: "phase11-fix03-08-pull-refresh-video")

        app.buttons["navbar.calendar"].tap()
        XCTAssertTrue(anyElement("calendar.root", in: app).waitForExistence(timeout: 5))
        app.swipeDown()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(app.buttons["navbar.calendar"].exists)
        try saveScreenshot(named: "phase11-fix03-09-pull-refresh-calendar")
        app.terminate()
    }

    private func assertPhase2Layout(for state: String, app: XCUIApplication) {
        switch state {
        case "login", "login-invalid":
            let card = anyElement("login-card", in: app)
            XCTAssertTrue(card.waitForExistence(timeout: 2), "Missing login card")
            XCTAssertGreaterThanOrEqual(card.frame.width, 340)

            let submit = app.buttons["login-submit"]
            XCTAssertTrue(submit.waitForExistence(timeout: 2), "Missing login submit")
            XCTAssertGreaterThanOrEqual(submit.frame.width, 300)
            XCTAssertGreaterThanOrEqual(submit.frame.height, 43)

        case "loading":
            let logo = anyElement("session-bootstrap-logo", in: app)
            XCTAssertTrue(logo.waitForExistence(timeout: 2), "Missing CreativeHub bootstrap logo")
            let ring = anyElement("loading-ring", in: app)
            XCTAssertTrue(ring.waitForExistence(timeout: 2), "Missing custom loading ring")
            XCTAssertGreaterThanOrEqual(round(ring.frame.width), 54)
            XCTAssertLessThanOrEqual(round(ring.frame.width), 58)
            XCTAssertGreaterThanOrEqual(round(ring.frame.height), 54)
            XCTAssertLessThanOrEqual(round(ring.frame.height), 58)
            XCTAssertFalse(app.staticTexts["Tổng quan"].exists, "Loading state should not flash authenticated shell")

        case "empty", "load-error", "offline":
            let title = anyElement("system-state-title", in: app)
            XCTAssertTrue(title.waitForExistence(timeout: 2), "Missing centered state title")
            XCTAssertLessThan(abs(title.frame.midX - app.frame.midX), 8)
            XCTAssertFalse(app.buttons["system-state-back"].exists, "\(state) must not expose a no-op back button")

            if state == "load-error" || state == "offline" {
                assertFullWidthButton("system-state-primary-action", in: app)
            }

        case "forbidden":
            let back = app.buttons["system-state-back"]
            XCTAssertTrue(back.waitForExistence(timeout: 2), "Missing state back control")
            XCTAssertGreaterThanOrEqual(back.frame.width, 36)
            XCTAssertGreaterThanOrEqual(back.frame.height, 36)

            let title = anyElement("system-state-title", in: app)
            XCTAssertTrue(title.waitForExistence(timeout: 2), "Missing centered state title")
            XCTAssertLessThan(abs(title.frame.midY - back.frame.midY), 4)
            XCTAssertLessThan(abs(title.frame.midX - app.frame.midX), 8)
            assertFullWidthButton("system-state-secondary-action", in: app)

        case "session-expired":
            XCTAssertFalse(app.buttons["system-state-back"].exists)
            assertFullWidthButton("system-state-primary-action", in: app)

        default:
            XCTAssertTrue(app.staticTexts["Tổng quan"].exists)
            XCTAssertTrue(app.buttons["Video"].exists)
            XCTAssertTrue(app.buttons["Lịch quay"].exists)
        }
    }

    private func assertFullWidthButton(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 2), "Missing \(identifier)")
        XCTAssertGreaterThanOrEqual(button.frame.width, 280)
        XCTAssertGreaterThanOrEqual(button.frame.height, 40)
    }

    private func anyElement(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func scrollUntilVisible(_ identifier: String, in app: XCUIApplication, maxSwipes: Int = 5) {
        let element = anyElement(identifier, in: app)
        var attempts = 0
        while !element.exists && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
    }

    private func tapStaticText(_ label: String, in app: XCUIApplication, maxSwipes: Int = 2) {
        let element = app.staticTexts[label]
        XCTAssertTrue(element.waitForExistence(timeout: 2), "Missing \(label)")
        var attempts = 0
        while !element.isHittable && attempts < maxSwipes {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
            attempts += 1
        }
        XCTAssertTrue(element.isHittable, "\(label) is not hittable")
        element.tap()
    }

    private func selectTimeScope(_ label: String, prefix: String, in app: XCUIApplication) {
        let menu = app.buttons["timeScopeButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 2), "Missing \(prefix) time scope button")
        menu.tap()
        let option = app.buttons[timeScopeOptionIdentifier(for: label)]
        XCTAssertTrue(option.waitForExistence(timeout: 2), "Missing \(label) time scope option")
        option.tap()
    }

    private func timeScopeOptionIdentifier(for label: String) -> String {
        switch label {
        case "Ngày": "timeScopeDay"
        case "Tuần": "timeScopeWeek"
        case "Tháng": "timeScopeMonth"
        default: label
        }
    }

    private func openProfileFromVideo(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["navbar.video"].waitForExistence(timeout: 5))
        app.buttons["navbar.video"].tap()
        XCTAssertTrue(app.buttons["navbar.video"].waitForExistence(timeout: 2))
        app.buttons["topbar.profile"].tap()
        XCTAssertTrue(anyElement("secondary.profile", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("profile.root", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["navbar.video"].waitForExistence(timeout: 1))
    }

    private func assertUnsupportedProfilePreferencesAbsent(in app: XCUIApplication) {
        XCTAssertFalse(anyElement("profile.no-preferences", in: app).exists)
        XCTAssertFalse(app.staticTexts["Tùy chọn ứng dụng"].exists)
        XCTAssertFalse(app.staticTexts["Theme"].exists)
        XCTAssertFalse(app.staticTexts["Ngôn ngữ"].exists)
        XCTAssertFalse(app.staticTexts["Thông báo"].exists)
        XCTAssertFalse(app.staticTexts["Chưa có cấu hình tài khoản"].exists)
        XCTAssertFalse(app.staticTexts["Không có preference production"].exists)
    }

    private func replaceText(in textField: XCUIElement, with text: String, app: XCUIApplication) {
        XCTAssertTrue(textField.waitForExistence(timeout: 2), "Missing field for replacement")
        textField.tap()
        textField.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()
        let currentValue = (textField.value as? String) ?? ""
        if !currentValue.isEmpty {
            textField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count + 4))
        }
        textField.typeText(text)
    }

    private func launch(
        _ app: XCUIApplication,
        phase2State: String,
        phase3QAHarness: Bool = false,
        phase4Fixture: String? = nil,
        phase4Month: String? = nil,
        phase5Fixture: String? = nil,
        phase5Date: String? = nil,
        phase5Permission: String? = nil,
        phase6Fixture: String? = nil,
        phase6Month: String? = nil,
        phase6Permission: String? = nil,
        phase7Fixture: String? = nil,
        phase7Month: String? = nil,
        phase7Permission: String? = nil,
        phase8Fixture: String? = nil,
        phase8Permission: String? = nil,
        phase9Fixture: String? = nil,
        phase10Fixture: String? = nil,
        phase11Scope: String? = "month",
        phase11Date: String? = nil,
        phase11ProfileID: String? = nil,
        phase11Fix02LoginFixture: Bool = false,
        phase11Fix03SignOutDelayMS: Int? = nil,
        timeScopeDefaultsSuite: String = "CreativeHubUITests.\(UUID().uuidString)"
    ) {
        app.launchEnvironment["CREATIVEHUB_PHASE2_STATE"] = phase2State
        app.launchEnvironment["CREATIVEHUB_TIME_SCOPE_DEFAULTS_SUITE"] = timeScopeDefaultsSuite
        if phase3QAHarness {
            app.launchEnvironment["CREATIVEHUB_PHASE3_QA_HARNESS"] = "1"
        }
        if let phase4Fixture {
            app.launchEnvironment["CREATIVEHUB_PHASE4_OVERVIEW_FIXTURE"] = phase4Fixture
        }
        if let phase4Month {
            app.launchEnvironment["CREATIVEHUB_PHASE4_MONTH"] = phase4Month
        }
        if let phase5Fixture {
            app.launchEnvironment["CREATIVEHUB_PHASE5_CALENDAR_FIXTURE"] = phase5Fixture
        }
        if let phase5Date {
            app.launchEnvironment["CREATIVEHUB_PHASE5_DATE"] = phase5Date
        }
        if let phase5Permission {
            app.launchEnvironment["CREATIVEHUB_PHASE5_CALENDAR_PERMISSION"] = phase5Permission
        }
        if let phase6Fixture {
            app.launchEnvironment["CREATIVEHUB_PHASE6_VIDEO_TASKS_FIXTURE"] = phase6Fixture
        }
        if let phase6Month {
            app.launchEnvironment["CREATIVEHUB_PHASE6_MONTH"] = phase6Month
        }
        if let phase6Permission {
            app.launchEnvironment["CREATIVEHUB_PHASE6_VIDEO_TASKS_PERMISSION"] = phase6Permission
        }
        if let phase7Fixture {
            app.launchEnvironment["CREATIVEHUB_PHASE7_CONTENT_PLAN_FIXTURE"] = phase7Fixture
        }
        if let phase7Month {
            app.launchEnvironment["CREATIVEHUB_PHASE7_MONTH"] = phase7Month
        }
        if let phase7Permission {
            app.launchEnvironment["CREATIVEHUB_PHASE7_CONTENT_PLAN_PERMISSION"] = phase7Permission
        }
        if let phase8Fixture {
            app.launchEnvironment["CREATIVEHUB_PHASE8_MEMBERS_FIXTURE"] = phase8Fixture
        }
        if let phase8Permission {
            app.launchEnvironment["CREATIVEHUB_PHASE8_MEMBERS_PERMISSION"] = phase8Permission
        }
        if let phase9Fixture {
            app.launchEnvironment["CREATIVEHUB_PHASE9_NOTIFICATIONS_FIXTURE"] = phase9Fixture
        }
        if let phase10Fixture {
            app.launchEnvironment["CREATIVEHUB_PHASE10_PROFILE_FIXTURE"] = phase10Fixture
        }
        if let phase11Scope {
            app.launchEnvironment["CREATIVEHUB_PHASE11_SCOPE"] = phase11Scope
        }
        if let phase11Date {
            app.launchEnvironment["CREATIVEHUB_PHASE11_DATE"] = phase11Date
        }
        if let phase11ProfileID {
            app.launchEnvironment["CREATIVEHUB_PHASE11_PROFILE_ID"] = phase11ProfileID
        }
        if phase11Fix02LoginFixture {
            app.launchEnvironment["CREATIVEHUB_PHASE11_FIX02_LOGIN_FIXTURE"] = "1"
        }
        if let phase11Fix03SignOutDelayMS {
            app.launchEnvironment["CREATIVEHUB_PHASE11_FIX03_SIGNOUT_DELAY_MS"] = "\(phase11Fix03SignOutDelayMS)"
        }
        app.launch()
    }

    private func saveScreenshot(named name: String) throws {
        let directory = ProcessInfo.processInfo.environment["CREATIVEHUB_SNAPSHOT_DIR"]
            .flatMap { $0.isEmpty ? nil : $0 }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("QA/Snapshots", isDirectory: true)

        let url = directory.appendingPathComponent("\(name).png")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: url, options: .atomic)
    }
}
