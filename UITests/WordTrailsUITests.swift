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
        XCTAssertTrue(app.staticTexts["Shortest possible route"].exists)
        app.swipeUp(); screenshot("06-Complete",app)
        app.buttons["shareResult"].tap()
        XCTAssertTrue(app.buttons["shareCard"].waitForExistence(timeout:10))
        screenshot("12-Share-Card",app)
        app.buttons["Done"].tap()
        app.navigationBars.buttons.element(boundBy:0).tap()
        tapAfterScrolling(app.buttons["practiceTrail"],app)
        XCTAssertTrue(app.textFields["wordInput"].waitForExistence(timeout:10))
        app.navigationBars.buttons.element(boundBy:0).tap()
        tapAfterScrolling(app.buttons["completedTrailHistory"],app)
        let attempt=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","completedAttempt-")).firstMatch
        XCTAssertTrue(attempt.waitForExistence(timeout:10));attempt.tap()
        XCTAssertEqual(app.staticTexts["savedParResult"].label,"1 under par")
        XCTAssertTrue(app.staticTexts["Shortest possible route"].exists)
        XCTAssertFalse(app.textFields["wordInput"].exists)
        screenshot("13-Saved-Completed-Trail",app)
        app.buttons["shareSavedResult"].tap()
        XCTAssertTrue(app.buttons["shareCard"].waitForExistence(timeout:10))
        app.buttons["Done"].tap()
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.navigationBars.buttons.element(boundBy:0).tap()
        tapAfterScrolling(app.buttons["continueTrail"],app)
        XCTAssertTrue(app.textFields["wordInput"].waitForExistence(timeout:10))
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
        for _ in 0..<3 {app.swipeUp()}
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Meadow")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Woodland")).firstMatch.exists)
        screenshot("14-Trails-Footer",app)
        app.tabBars.buttons["Co-op"].tap(); screenshot("03-Coop",app)
        app.tabBars.buttons["Garden"].tap(); screenshot("04-Garden",app)
        app.tabBars.buttons["Stats"].tap(); screenshot("05-Statistics",app)
    }
    func testDailyCompletedAttemptOpensWithoutStartingReplay() throws {
        let app=XCUIApplication();app.launchArguments=["--ui-test"];app.launch()
        XCTAssertTrue(app.buttons["Take the first step"].waitForExistence(timeout:30))
        tapAfterScrolling(app.buttons["Take the first step"],app)
        tapAfterScrolling(app.buttons["Walk today’s trail"],app)
        for _ in 0..<12 {
            let hint=app.buttons["Hint"]
            tapAfterScrolling(hint,app)
            let message=app.staticTexts["gameMessage"]
            XCTAssertTrue(message.waitForExistence(timeout:5))
            let parts=message.label.split(separator:" ")
            guard parts.count>1 else{XCTFail("No hint word");return}
            let word=String(parts[1]).trimmingCharacters(in:.punctuationCharacters)
            let input=app.textFields["wordInput"];input.tap();input.typeText(word+"\n")
            if app.alerts.buttons["Lovely"].waitForExistence(timeout:1){app.alerts.buttons["Lovely"].tap();break}
        }
        XCTAssertTrue(app.staticTexts["Shortest possible route"].waitForExistence(timeout:5))
        app.navigationBars.buttons.element(boundBy:0).tap()
        XCTAssertTrue(app.buttons["viewCompletedDaily"].waitForExistence(timeout:10))
        XCTAssertTrue(app.buttons["replayDaily"].exists)
        screenshot("15-Completed-Daily-Home",app)
        tapAfterScrolling(app.buttons["viewCompletedDaily"],app)
        XCTAssertTrue(app.buttons["shareSavedResult"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["Shortest possible route"].exists)
        app.tabBars.buttons["Stats"].tap()
        let attempts=app.cells.containing(.staticText,identifier:"Trails attempted").firstMatch
        let completed=app.cells.containing(.staticText,identifier:"Trails completed").firstMatch
        XCTAssertTrue(attempts.staticTexts["1"].exists)
        XCTAssertTrue(completed.staticTexts["1"].exists)
    }
    private func tapAfterScrolling(_ element:XCUIElement,_ app:XCUIApplication){
        XCTAssertTrue(element.waitForExistence(timeout:15))
        for _ in 0..<6 {if element.isHittable{break};app.swipeUp()}
        element.tap()
    }
    private func screenshot(_ name:String,_ app:XCUIApplication) {
        let attachment = XCTAttachment(screenshot:app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
