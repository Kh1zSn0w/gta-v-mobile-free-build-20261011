import XCTest

final class LauncherTests: XCTestCase {
    func testMaximumSwipeSensitivityPersists() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["launcher.play"].waitForExistence(timeout: 10))
        app.buttons["launcher.settings.Controls"].tap()
        let look = app.sliders["Look speed"]
        let aim = app.sliders["Aim look speed"]
        XCTAssertTrue(look.waitForExistence(timeout: 4))
        look.adjust(toNormalizedSliderPosition: 1)
        aim.adjust(toNormalizedSliderPosition: 1)
        app.buttons["Done"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["launcher.play"].waitForExistence(timeout: 10))
        app.buttons["launcher.settings.Controls"].tap()
        XCTAssertTrue(look.waitForExistence(timeout: 4))
        XCTAssertEqual(look.value as? String, "100%")
        XCTAssertEqual(aim.value as? String, "100%")
    }
    func testFreeScreenDragReachesCameraWithoutRightStick() {
        XCUIDevice.shared.orientation = .landscapeRight
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--test-touch-controls"]
        app.launch()
        let result = app.staticTexts["controls.swipe-result"]
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.30))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.30))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertEqual(result.label, "Swipe delivered right")
        app.terminate()
        app.launch()
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        end.press(forDuration: 0.1, thenDragTo: start)
        XCTAssertEqual(result.label, "Swipe delivered left")
    }
    func testPlayOffersBothModesWithoutCancel() {
        let app = XCUIApplication()
        app.launch()
        let play = app.buttons["launcher.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        play.tap()
        XCTAssertTrue(app.buttons["launcher.story"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["launcher.sandbox"].exists)
        XCTAssertFalse(app.buttons["Cancel"].exists)
    }

    func testStoryAndSandboxDeliverDistinctSelections() {
        let app = XCUIApplication()
        app.launch()
        let play = app.buttons["launcher.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        play.tap()
        app.buttons["launcher.story"].tap()
        let selected = app.staticTexts["Story selected"].waitForExistence(timeout: 5)
        if !selected {
            print("MODE_DIAGNOSTICS " + app.debugDescription)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        XCTAssertTrue(selected)
        play.tap()
        app.buttons["launcher.sandbox"].tap()
        XCTAssertTrue(app.staticTexts["Sandbox selected"].waitForExistence(timeout: 3))
    }

    func testSettingsRemainReachableBelowPlay() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["launcher.play"].waitForExistence(timeout: 10))
        for name in ["Graphics", "Controls", "Motion", "Game files", "Connection"] {
            let row = app.buttons["launcher.settings.\(name)"]
            for _ in 0..<4 where !row.isHittable { app.swipeUp() }
            XCTAssertTrue(row.isHittable, "Missing settings row: \(name)")
        }
    }

    func testNoDecorativeStatusOnHome() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["launcher.play"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Touch controls ready"].exists)
        XCTAssertTrue(app.staticTexts["Downloaded locally"].exists)
    }

    func test120FPSSelectionPersists() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["launcher.play"].waitForExistence(timeout: 10))
        app.buttons["launcher.settings.Graphics"].tap()
        let fps = app.buttons["graphics.fps"]
        XCTAssertTrue(fps.waitForExistence(timeout: 4))
        fps.tap()
        let high = app.buttons["120 FPS"]
        XCTAssertTrue(high.waitForExistence(timeout: 3))
        high.tap()
        XCTAssertTrue(app.buttons["graphics.fps"].label.contains("120 FPS"))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["launcher.settings.Graphics"].label.contains("Graphics"))
        app.buttons["launcher.settings.Graphics"].tap()
        XCTAssertTrue(app.buttons["graphics.fps"].label.contains("120 FPS"))
    }

    func testSwipeControlsAndDetailSettingsAreAvailable() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["launcher.play"].waitForExistence(timeout: 10))
        app.buttons["launcher.settings.Controls"].tap()
        XCTAssertTrue(app.staticTexts["Swipe look sensitivity"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Aim swipe sensitivity"].exists)
        app.buttons["Done"].tap()
        app.buttons["launcher.settings.Graphics"].tap()
        XCTAssertTrue(app.switches["Sharper textures and models"].waitForExistence(timeout: 3))
    }

    func testGraphicsAndFilesOpenFocusedPages() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["launcher.play"].waitForExistence(timeout: 10))
        app.buttons["launcher.settings.Graphics"].tap()
        XCTAssertTrue(app.navigationBars["Graphics"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.sliders["Resolution scale"].exists)
        XCTAssertFalse(app.staticTexts["Tilt steering"].exists)
        app.buttons["Done"].tap()
        let files = app.buttons["launcher.settings.Game files"]
        for _ in 0..<4 where !files.isHittable { app.swipeUp() }
        files.tap()
        XCTAssertTrue(app.staticTexts["Downloaded locally"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.sliders["Resolution scale"].exists)
    }
}
