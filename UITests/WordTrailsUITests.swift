import XCTest

final class WordTrailsUITests: XCTestCase {
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
