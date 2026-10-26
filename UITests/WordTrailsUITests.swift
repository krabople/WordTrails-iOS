import XCTest

final class WordTrailsUITests: XCTestCase {
    func testDarkModeAtLargeTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test","--example-trail","--dark-mode","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["continueTrail"].waitForExistence(timeout:30))
        screenshot("09-Dark-LargeText",app)
        app.tabBars.buttons["Garden"].tap()
        screenshot("10-Garden-Dark-LargeText",app)
    }
    func testCompleteSoloTrailAndEarnSeeds() throws {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test","--example-trail"]; app.launch()
        XCTAssertTrue(app.buttons["continueTrail"].waitForExistence(timeout:30))
        app.buttons["continueTrail"].tap()
        let input = app.textFields["wordInput"]
        XCTAssertTrue(input.waitForExistence(timeout:10))
        for word in ["COT","DOT","DOG"] { input.tap(); input.typeText(word+"\n") }
        XCTAssertTrue(app.alerts["New badges earned"].waitForExistence(timeout:5))
        screenshot("11-New-Badges",app)
        app.alerts.buttons["Lovely"].tap()
        XCTAssertTrue(app.staticTexts["Trail complete"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["+5 seeds for your garden"].exists)
        XCTAssertEqual(app.staticTexts["parResult"].label,"1 under par")
        app.swipeUp(); screenshot("06-Complete",app)
        app.buttons["shareResult"].tap()
        XCTAssertTrue(app.buttons["shareCard"].waitForExistence(timeout:10))
        screenshot("12-Share-Card",app)
    }
    func testRemindersAreOptInAndStatisticsAreAvailable() throws {
        let app=XCUIApplication();app.launchArguments=["--ui-test","--example-trail"];app.launch()
        XCTAssertTrue(app.buttons["reminderSettings"].waitForExistence(timeout:30))
        app.buttons["reminderSettings"].tap()
        let toggle=app.switches["dailyReminderToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout:10));XCTAssertEqual(toggle.value as? String,"0")
        screenshot("07-Reminder",app)
        app.buttons["Done"].tap();app.tabBars.buttons["Stats"].tap()
        XCTAssertTrue(app.staticTexts["Trails attempted"].waitForExistence(timeout:10))
        app.buttons["difficultyStats3"].tap()
        XCTAssertTrue(app.staticTexts["Completed"].exists)
        screenshot("08-Statistics",app)
    }
    func testFirstTrailAndCollections() throws {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test"]; app.launch()
        app.buttons["Take the first step"].waitForExistence(timeout:30)
        for _ in 0..<5 { if app.buttons["Take the first step"].isHittable { break }; app.swipeUp() }; app.buttons["Take the first step"].tap()
        XCTAssertTrue(app.buttons["Walk today’s trail"].waitForExistence(timeout:30))
        screenshot("01-Trails",app)
        app.buttons["Walk today’s trail"].tap()
        XCTAssertTrue(app.textFields["wordInput"].waitForExistence(timeout:10))
        screenshot("02-Playing",app)
        app.textFields["wordInput"].tap(); app.textFields["wordInput"].typeText("ZZZZ\n")
        XCTAssertTrue(app.staticTexts["gameMessage"].waitForExistence(timeout:5))
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.tabBars.buttons["Co-op"].tap(); screenshot("03-Coop",app)
        app.tabBars.buttons["Garden"].tap(); screenshot("04-Garden",app)
        app.tabBars.buttons["Stats"].tap(); screenshot("05-Statistics",app)
    }
    private func screenshot(_ name:String,_ app:XCUIApplication) {
        let attachment = XCTAttachment(screenshot:app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
