import XCTest

final class SandboxSaveTests: XCTestCase {
    func testSandboxSaveButtonReportsSuccess() {
        let app = XCUIApplication()
        app.launchArguments = ["--trainer-preview"]
        app.launch()
        let save = app.descendants(matching: .any).matching(identifier: "trainer.action.182").firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["Sandbox saved · Resume here next launch."].waitForExistence(timeout: 5))
    }

    func testSandboxSaveIsUnavailableInStory() {
        let app = XCUIApplication()
        app.launchArguments = ["--trainer-preview", "--trainer-story"]
        app.launch()
        let save = app.descendants(matching: .any).matching(identifier: "trainer.action.182").firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        XCTAssertFalse(save.isEnabled)
    }
}
