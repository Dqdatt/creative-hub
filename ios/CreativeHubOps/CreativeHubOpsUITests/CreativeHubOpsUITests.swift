import XCTest

@MainActor
final class CreativeHubOpsUITests: XCTestCase {
    func testAppLaunchesToLoginOrDashboard() {
        let app = XCUIApplication()
        app.launch()
        let loginTitleExists = app.staticTexts["CreativeHub Ops"].waitForExistence(timeout: 5)
        let dashboardTitleExists = app.staticTexts["Tổng quan"].waitForExistence(timeout: 2)
        XCTAssertTrue(loginTitleExists || dashboardTitleExists)
    }

    func testPhase3DNotificationsSurfaceSnapshot() throws {
        let app = XCUIApplication()
        app.launch()

        guard app.staticTexts["Tổng quan"].waitForExistence(timeout: 6) else {
            throw XCTSkip("Phase 3D screenshot QA needs an authenticated simulator session.")
        }

        app.buttons["Tác vụ"].tap()
        XCTAssertTrue(app.staticTexts["Thông báo"].waitForExistence(timeout: 5))

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "phase3d-notifications"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPhase3DShootDetailSurfaceSnapshot() throws {
        let app = XCUIApplication()
        app.launch()

        guard app.staticTexts["Tổng quan"].waitForExistence(timeout: 6) else {
            throw XCTSkip("Phase 3D screenshot QA needs an authenticated simulator session.")
        }

        app.buttons["Tác vụ"].tap()
        XCTAssertTrue(app.staticTexts["Thông báo"].waitForExistence(timeout: 5))

        let shootNotification = app.staticTexts["Lịch quay mới"].firstMatch
        guard shootNotification.waitForExistence(timeout: 5) else {
            throw XCTSkip("No linked shoot notification is available for detail screenshot QA.")
        }

        shootNotification.tap()
        XCTAssertTrue(app.staticTexts["Chi tiết Lịch quay"].waitForExistence(timeout: 5))

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "phase3d-shoot-detail"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPhase3DCreateTaskSheetSnapshot() throws {
        let app = XCUIApplication()
        app.launch()

        guard app.staticTexts["Tổng quan"].waitForExistence(timeout: 6) else {
            throw XCTSkip("Phase 3D screenshot QA needs an authenticated simulator session.")
        }

        app.buttons["Tạo mới"].tap()
        XCTAssertTrue(app.staticTexts["Thêm Video Task"].waitForExistence(timeout: 5))

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "phase3d-create-task-sheet"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
