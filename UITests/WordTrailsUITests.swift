import XCTest

final class WordTrailsUITests: XCTestCase {
    func testCompleteSoloTrailAndEarnSeeds() throws {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test","--example-trail"]; app.launch()
        XCTAssertTrue(app.buttons["continueTrail"].waitForExistence(timeout:30))
        app.buttons["continueTrail"].tap()
        let input = app.textFields["wordInput"]
        XCTAssertTrue(input.waitForExistence(timeout:10))
        for word in ["COT","DOT","DOG"] { input.tap(); input.typeText(word+"\n") }
        XCTAssertTrue(app.staticTexts["Trail complete"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["+5 seeds for your garden"].exists)
        screenshot("06-Complete",app)
    }
    func testBotCoopAndSharedGarden() throws {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test","--example-trail","--example-coop"]; app.launch()
        XCTAssertTrue(app.buttons["continueTrail"].waitForExistence(timeout:30))
        app.buttons["continueTrail"].tap()
        let input = app.textFields["wordInput"]
        XCTAssertTrue(input.waitForExistence(timeout:10))
        input.tap(); input.typeText("COT\n")
        XCTAssertTrue(app.staticTexts["Oak · Bot"].waitForExistence(timeout:10))
        input.tap(); input.typeText("DOG\n")
        XCTAssertTrue(app.staticTexts["Trail complete"].waitForExistence(timeout:5))
        screenshot("07-Coop",app)
        app.navigationBars.buttons.element(boundBy:0).tap(); app.tabBars.buttons["Garden"].tap()
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(app.staticTexts["You + Oak · Bot"].waitForExistence(timeout:5))
        screenshot("08-SharedGarden",app)
    }
    func testFirstTrailAndCollections() throws {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test"]; app.launch()
        app.buttons["Take the first step"].waitForExistence(timeout:30)
        app.swipeUp(); app.buttons["Take the first step"].tap()
        XCTAssertTrue(app.buttons["Walk today’s trail"].waitForExistence(timeout:30))
        screenshot("01-Trails",app)
        app.buttons["Walk today’s trail"].tap()
        XCTAssertTrue(app.textFields["wordInput"].waitForExistence(timeout:10))
        screenshot("02-Playing",app)
        app.textFields["wordInput"].tap(); app.textFields["wordInput"].typeText("ZZZZ\n")
        XCTAssertTrue(app.staticTexts["gameMessage"].waitForExistence(timeout:5))
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.tabBars.buttons["Together"].tap(); screenshot("03-Together",app)
        app.tabBars.buttons["Garden"].tap(); screenshot("04-Garden",app)
        app.tabBars.buttons["Journal"].tap(); screenshot("05-Journal",app)
    }
    private func screenshot(_ name:String,_ app:XCUIApplication) {
        let attachment = XCTAttachment(screenshot:app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
