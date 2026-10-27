import XCTest
import UIKit

final class StoreMediaTests:XCTestCase {
    override func setUp(){continueAfterFailure=false}
    private var app=XCUIApplication()
    private var documents:URL{FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]}
    private func launch(_ extra:[String]=[],orientation:UIDeviceOrientation = .portrait) {
        app.terminate()
        XCUIDevice.shared.orientation = orientation
        app=XCUIApplication();app.launchArguments=["--ui-test","--store-capture"]+extra;app.launch()
        XCTAssertTrue(app.buttons["Walk today’s trail"].waitForExistence(timeout:30))
    }
    private func tap(_ item:XCUIElement) {
        XCTAssertTrue(item.waitForExistence(timeout:15))
        for _ in 0..<8{if item.isHittable{break};app.swipeUp()}
        item.tap()
    }
    private func capture(_ name:String) throws {
        Thread.sleep(forTimeInterval:0.8)
        let shot=app.screenshot()
        let directory=documents.appendingPathComponent("store-captures",isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        try shot.pngRepresentation.write(to:directory.appendingPathComponent(name+".png"))
        let attachment=XCTAttachment(screenshot:shot);attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    func testStoreScreenshots() throws {
        launch()
        try capture("01-Daily")
        tap(app.buttons["continueTrail"])
        XCTAssertTrue(app.textFields["wordInput"].waitForExistence(timeout:10))
        try capture("02-Wordplay")
        launch(["--summit"]);tap(app.buttons["continueTrail"])
        try capture("03-Summit")
        launch(["--completed"])
        tap(app.buttons["completedTrailHistory"])
        tap(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","completedAttempt-")).firstMatch)
        XCTAssertTrue(app.buttons["shareSavedResult"].waitForExistence(timeout:10))
        try capture("04-Shortest")
        app.navigationBars.buttons.element(boundBy:0).tap()
        try capture("05-History")
        tap(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","completedAttempt-")).firstMatch)
        tap(app.buttons["shareSavedResult"])
        XCTAssertTrue(app.buttons["shareCard"].waitForExistence(timeout:10))
        try capture("06-Share")
        app.buttons["Done"].tap()
        tap(app.buttons["Garden"].firstMatch)
        try capture("07-Garden")
        tap(app.buttons["Stats"].firstMatch)
        try capture("08-Statistics")
        tap(app.buttons["badgeCollection"])
        XCTAssertTrue(app.navigationBars["Your badges"].waitForExistence(timeout:10))
        try capture("09-Badges")
        launch();tap(app.buttons["reminderSettings"])
        XCTAssertTrue(app.switches["dailyReminderToggle"].waitForExistence(timeout:10))
        try capture("10-Reminder")
    }
    func testZZIPadRotationAndShare() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else{throw XCTSkip("iPad layout check")}
        // Start in landscape so XCTest builds its input coordinate map there.
        // Then verify that rotating the live game preserves the edited route.
        launch(orientation:.landscapeLeft);tap(app.buttons["continueTrail"])
        XCTAssertTrue(app.textFields["wordInput"].waitForExistence(timeout:10))
        try capture("QA-iPad-Landscape")
        let input=app.textFields["wordInput"]
        input.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout:4){
            // A rotated simulator can retain stale element tap coordinates.
            // Retry in the application's coordinate space before typing.
            let frame=input.frame
            app.coordinate(withNormalizedOffset:CGVector(dx:0,dy:0)).withOffset(CGVector(dx:frame.midX,dy:frame.midY)).tap()
        }
        input.typeText("HUNK\n")
        XCTAssertFalse(app.staticTexts["gameMessage"].exists)
        XCUIDevice.shared.orientation = .portrait
        try capture("QA-iPad-Portrait")
        launch(["--completed"])
        tap(app.buttons["completedTrailHistory"])
        tap(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","completedAttempt-")).firstMatch)
        tap(app.buttons["shareSavedResult"])
        tap(app.buttons["shareCard"])
        let copy=app.descendants(matching:.any).matching(NSPredicate(format:"label == %@","Copy")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout:15),"The native iPad share sheet should open safely")
        try capture("QA-iPad-System-Share")
    }
    func testRecordGameplay() throws {
        launch(["--record-game"]);tap(app.buttons["continueTrail"])
        XCTAssertTrue(app.textFields["wordInput"].waitForExistence(timeout:10))
        try Data().write(to:documents.appendingPathComponent("store-video-ready"))
        let started=documents.appendingPathComponent("store-video-started")
        let deadline=Date().addingTimeInterval(90)
        while !FileManager.default.fileExists(atPath:started.path) && Date()<deadline{Thread.sleep(forTimeInterval:0.25)}
        XCTAssertTrue(FileManager.default.fileExists(atPath:started.path))
        Thread.sleep(forTimeInterval:2)
        let input=app.textFields["wordInput"]
        for word in ["CAN","PAN","PIN","PIE"] {
            input.tap();input.typeText(word+"\n");Thread.sleep(forTimeInterval:1.1)
        }
        if app.alerts.buttons["Lovely"].waitForExistence(timeout:1){app.alerts.buttons["Lovely"].tap()}
        XCTAssertTrue(app.staticTexts["Shortest possible route"].waitForExistence(timeout:10))
        Thread.sleep(forTimeInterval:3)
        tap(app.buttons["shareResult"])
        XCTAssertTrue(app.buttons["shareCard"].waitForExistence(timeout:10))
        Thread.sleep(forTimeInterval:3)
        app.buttons["Done"].tap();tap(app.buttons["Garden"].firstMatch)
        Thread.sleep(forTimeInterval:3)
        try Data().write(to:documents.appendingPathComponent("store-video-done"))
    }
}
