import XCTest

final class FinalControlsTests: XCTestCase {
    func testFrameRateMenuStartsAt60AndKeeps120() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["launcher.settings.Graphics"].waitForExistence(timeout: 10))
        app.buttons["launcher.settings.Graphics"].tap()
        let fps = app.buttons["graphics.fps"]
        XCTAssertTrue(fps.waitForExistence(timeout: 4))
        XCTAssertFalse(fps.label.contains("30 FPS"))
        fps.tap()
        XCTAssertTrue(app.buttons["60 FPS"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["30 FPS"].exists)
        app.buttons["120 FPS"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["launcher.settings.Graphics"].waitForExistence(timeout: 10))
        app.buttons["launcher.settings.Graphics"].tap()
        XCTAssertTrue(fps.waitForExistence(timeout: 4))
        XCTAssertTrue(fps.label.contains("120 FPS"))
        fps.tap()
        app.buttons["60 FPS"].tap()
        XCTAssertTrue(fps.label.contains("60 FPS"))
    }

    func testMovedFireButtonPersistsAndResetRestoresPosition() {
        XCUIDevice.shared.orientation = .landscapeRight
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        func openEditor() {
            XCTAssertTrue(app.buttons["launcher.settings.Controls"].waitForExistence(timeout: 10))
            app.buttons["launcher.settings.Controls"].tap()
            let editor = app.descendants(matching: .any).matching(identifier: "controls.edit-layout").firstMatch
            XCTAssertTrue(editor.waitForExistence(timeout: 5))
            for _ in 0..<5 where !editor.isHittable { app.tables.firstMatch.swipeUp() }
            // XCTest can scroll a table cell into view when tapping. A global
            // application swipe may instead move the surrounding sheet.
            editor.tap()
            XCTAssertTrue(app.buttons["controls.layout-reset"].waitForExistence(timeout: 5))
        }
        app.launch()
        openEditor()
        app.buttons["controls.layout-reset"].tap()
        let fire = app.descendants(matching: .any).matching(identifier: "controls.button.fire").firstMatch
        XCTAssertTrue(fire.waitForExistence(timeout: 4))
        let original = fire.frame
        let origin = fire.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        origin.press(forDuration: 0.15, thenDragTo: origin.withOffset(CGVector(dx: -70, dy: -30)))
        let moved = fire.frame
        XCTAssertGreaterThan(abs(moved.midX - original.midX), 40)
        app.buttons["controls.layout-done"].tap()
        app.terminate()
        app.launch()
        openEditor()
        XCTAssertEqual(fire.frame.midX, moved.midX, accuracy: 4)
        XCTAssertEqual(fire.frame.midY, moved.midY, accuracy: 4)
        app.buttons["controls.layout-reset"].tap()
        XCTAssertEqual(fire.frame.midX, original.midX, accuracy: 4)
        XCTAssertEqual(fire.frame.midY, original.midY, accuracy: 4)
        app.buttons["controls.layout-done"].tap()
    }

    func testFireDragKeepsCameraControl() {
        XCUIDevice.shared.orientation = .landscapeRight
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--test-touch-controls"]
        app.launch()
        let fire = app.descendants(matching: .any).matching(identifier: "controls.button.fire").firstMatch
        XCTAssertTrue(fire.waitForExistence(timeout: 5))
        let origin = fire.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        origin.press(forDuration: 0.15, thenDragTo: origin.withOffset(CGVector(dx: -90, dy: 0)))
        XCTAssertTrue(app.staticTexts["Swipe delivered left"].waitForExistence(timeout: 3))
    }
}
