import XCTest

final class LauncherTests: XCTestCase {
    func testCharacterWardrobePoliceAndSuits() {
        let app = XCUIApplication()
        app.launchArguments = ["--trainer-preview"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Trainer"].waitForExistence(timeout: 10))
        let tabs = app.segmentedControls["trainer.categories"]
        tabs.buttons["Character"].tap()
        let police = app.descendants(matching: .any).matching(identifier: "trainer.action.101").firstMatch
        XCTAssertTrue(police.isEnabled); police.tap()
        XCTAssertTrue(app.staticTexts["Handed to game · Police officer · male"].waitForExistence(timeout: 4))
        tabs.buttons["Player"].tap(); tabs.buttons["Character"].tap()
        app.descendants(matching: .any).matching(identifier: "trainer.action.0").firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Customize outfit"].waitForExistence(timeout: 4))
        app.descendants(matching: .any).matching(identifier: "wardrobe.variant.0").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Style 2/3 · Colour 1/2"].waitForExistence(timeout: 4))
        app.descendants(matching: .any).matching(identifier: "wardrobe.variant.2").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Style 2/3 · Colour 2/2"].waitForExistence(timeout: 4))
        app.buttons["wardrobe.piece"].tap(); app.buttons["Hat / helmet"].tap()
        XCTAssertTrue(app.buttons["wardrobe.piece"].label.contains("Hat / helmet"))
        app.navigationBars.buttons["Trainer"].tap()
        tabs.buttons["Vehicles"].tap()
        let search = app.searchFields["Find a tool or vehicle"]
        search.tap(); search.typeText("Police Interceptor\n")
        app.descendants(matching: .any).matching(identifier: "trainer.action.87").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Handed to game · Police Interceptor"].waitForExistence(timeout: 4))
    }
    func testStoryBlocksSkinSwapAndAllowsClothes() {
        let app = XCUIApplication()
        app.launchArguments = ["--trainer-preview", "--trainer-story"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Trainer"].waitForExistence(timeout: 10))
        app.segmentedControls["trainer.categories"].buttons["Character"].tap()
        let police = app.descendants(matching: .any).matching(identifier: "trainer.action.101").firstMatch
        XCTAssertTrue(police.exists); XCTAssertFalse(police.isEnabled)
        app.descendants(matching: .any).matching(identifier: "trainer.action.0").firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Customize outfit"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "wardrobe.variant.0").firstMatch.isEnabled)
    }
    func testExpandedTrainerSearchTogglesWeatherAndReset() {
        let app = XCUIApplication()
        app.launchArguments = ["--trainer-preview"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Trainer"].waitForExistence(timeout: 10))
        let categories = app.segmentedControls["trainer.categories"]
        categories.buttons["Powers"].tap()
        let jump = app.descendants(matching: .any).matching(identifier: "trainer.action.16").firstMatch
        XCTAssertEqual(jump.value as? String, "OFF")
        jump.tap()
        XCTAssertTrue(app.staticTexts["Handed to game · Super jump"].waitForExistence(timeout: 3))
        XCTAssertEqual(jump.value as? String, "ON")
        categories.buttons["Vehicles"].tap()
        let search = app.searchFields["Find a tool or vehicle"]
        search.tap(); search.typeText("Rhino\n")
        let tank = app.descendants(matching: .any).matching(identifier: "trainer.action.79").firstMatch
        XCTAssertTrue(tank.waitForExistence(timeout: 3)); tank.tap()
        XCTAssertTrue(app.staticTexts["Handed to game · Rhino"].waitForExistence(timeout: 3))
        categories.buttons["World"].tap()
        search.tap(); search.typeText("Blizzard\n")
        app.descendants(matching: .any).matching(identifier: "trainer.action.44").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Handed to game · Blizzard"].waitForExistence(timeout: 3))
        categories.buttons["Powers"].tap()
        search.tap(); search.typeText("Reset powers\n")
        app.descendants(matching: .any).matching(identifier: "trainer.action.25").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Handed to game · Reset powers"].waitForExistence(timeout: 3))
        categories.buttons["Player"].tap(); categories.buttons["Powers"].tap()
        XCTAssertEqual(jump.value as? String, "OFF")
    }

    func testTrainerFlightIsReachableInLandscape() {
        let app = XCUIApplication()
        app.launchArguments = ["--trainer-preview"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Trainer"].waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.segmentedControls["trainer.categories"].buttons["Powers"].tap()
        let search = app.searchFields["Find a tool or vehicle"]
        search.tap(); search.typeText("Hover flight\n")
        let flight = app.descendants(matching: .any).matching(identifier: "trainer.action.24").firstMatch
        XCTAssertTrue(flight.waitForExistence(timeout: 4)); flight.tap()
        XCTAssertTrue(app.staticTexts["Handed to game · Hover flight · experimental"].waitForExistence(timeout: 4))
        XCTAssertEqual(flight.value as? String, "ON")
        flight.tap()
        let off = NSPredicate(format: "value == %@", "OFF")
        expectation(for: off, evaluatedWith: flight); waitForExpectations(timeout: 4)
    }

    func testTrainerRoutesPlayerVehicleAndWorldRequests() {
        let app = XCUIApplication()
        app.launchArguments = ["--test-touch-controls"]
        app.launch()
        XCTAssertTrue(app.buttons["Trainer"].waitForExistence(timeout: 10))
        app.buttons["Trainer"].tap()
        XCTAssertTrue(app.navigationBars["Trainer"].waitForExistence(timeout: 4))
        func action(_ command: Int) -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: "trainer.action.\(command)").firstMatch
        }
        let invincible = action(5)
        XCTAssertTrue(invincible.waitForExistence(timeout: 3))
        XCTAssertEqual(invincible.value as? String, "OFF")
        invincible.tap()
        let on = NSPredicate(format: "value == %@", "ON")
        expectation(for: on, evaluatedWith: invincible)
        waitForExpectations(timeout: 4)
        action(1).tap()
        XCTAssertTrue(app.staticTexts["Handed to game · Health & armor"].waitForExistence(timeout: 4))
        app.segmentedControls["trainer.categories"].buttons["Vehicles"].tap()
        action(7).tap()
        XCTAssertTrue(app.staticTexts["Handed to game · Comet"].waitForExistence(timeout: 4))
        app.segmentedControls["trainer.categories"].buttons["World"].tap()
        app.searchFields["Find a tool or vehicle"].tap()
        app.searchFields["Find a tool or vehicle"].typeText("Golden hour\n")
        let sunset = action(14)
        for _ in 0..<3 where !sunset.isHittable { app.tables.firstMatch.swipeUp() }
        XCTAssertTrue(sunset.isHittable)
        sunset.tap()
        XCTAssertTrue(app.staticTexts["Handed to game · Golden hour"].waitForExistence(timeout: 4))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Trainer"].waitForExistence(timeout: 4))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Trainer"].waitForExistence(timeout: 10))
        app.buttons["Trainer"].tap()
        XCTAssertTrue(action(5).waitForExistence(timeout: 4))
        XCTAssertEqual(action(5).value as? String, "OFF")
    }

    func testTrainerShowsUnavailableWithoutPretendingToApply() {
        let app = XCUIApplication()
        app.launchArguments = ["--test-touch-controls", "--trainer-unavailable"]
        app.launch()
        XCTAssertTrue(app.buttons["Trainer"].waitForExistence(timeout: 10))
        app.buttons["Trainer"].tap()
        XCTAssertTrue(app.staticTexts["Tools unlock when the player is ready and the game menu is closed."].waitForExistence(timeout: 4))
        let heal = app.descendants(matching: .any).matching(identifier: "trainer.action.1").firstMatch
        XCTAssertTrue(heal.exists)
        XCTAssertFalse(heal.isEnabled)
        XCTAssertFalse(app.staticTexts["Handed to game · Health & armor"].exists)
    }

    func testPersonalLauncherAndModeSheet() {
        let app = XCUIApplication(); app.launchArguments = ["--mode-picker"]; app.launch()
        XCTAssertTrue(app.buttons["launcher.story"].waitForExistence(timeout: 10))
        app.buttons["launcher.story"].tap()
        XCTAssertTrue(app.staticTexts["Story selected"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Forked by Zenyical"].exists)
    }
    func testNewControlsKeepPersonalCameraOption() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["launcher.settings.Controls"].waitForExistence(timeout: 10))
        app.buttons["launcher.settings.Controls"].tap()
        XCTAssertTrue(app.segmentedControls["Camera control"].waitForExistence(timeout: 4))
        let keep = app.switches["Keep driving camera angle"]
        for _ in 0..<8 where !keep.isHittable { app.tables.firstMatch.swipeUp() }
        XCTAssertTrue(keep.isHittable)
    }
}
