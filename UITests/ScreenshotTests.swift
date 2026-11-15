import XCTest

/// Not a test of behaviour: drives the real app to a handful of screens and saves a screenshot of each, for the
/// App Store listing. Run by the "iOS screenshots" workflow only (the regular UI test run skips this class).
/// Every scene starts from a fresh launch, so one scene failing to reach its screen never spoils the others.
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    // MARK: Scenes

    func test_01_home() {
        let app = launch()
        settle(6)
        shot("01-home")
        _ = app
    }

    func test_02_aWebPage() {
        let app = launch()
        go(app, to: "https://en.wikipedia.org/wiki/South_Africa")
        // Wait for the page to really load: the address bar shows the address once it has.
        let field = app.textFields["addressBarField"]
        let deadline = Date().addingTimeInterval(40)
        while Date() < deadline, !((field.value as? String) ?? "").contains("wikipedia") { settle(1) }
        settle(6)
        diagnose(app, "web-page")
        shot("02-web-page")
    }

    func test_03_askVision() {
        let app = launch(realVisionAI: true)
        let field = app.textFields["addressBarField"]
        guard field.waitForExistence(timeout: 8) else { return shot("03-ask-vision") }
        field.tap()
        field.typeText("Explain photosynthesis in simple words")
        app.buttons["newTabAIMode"].tap()
        let reply = app.staticTexts.element(matching: NSPredicate(format: "identifier BEGINSWITH 'chatAssistantMessage_'"))
        if reply.waitForExistence(timeout: 20) {
            let answered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT (label BEGINSWITH 'Asking') AND label != ''"), object: reply)
            _ = XCTWaiter().wait(for: [answered], timeout: 60)
        }
        settle(3)
        diagnose(app, "ask-vision")
        shot("03-ask-vision")
    }

    func test_04_studyTools() {
        let app = launch()
        tapMore(app)
        let education = element(app, "menu_education")
        if education.waitForExistence(timeout: 6) { education.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() } else { diagnose(app, "menu-missing-education") }
        settle(2)
        shot("04-study-tools")
    }

    func test_05_focus() {
        let app = launch()
        openInMore(app, "menu_focus")
        settle(3)
        shot("05-focus")
    }

    func test_06_rewards() {
        let app = launch()
        openInMore(app, "menu_rewards")
        settle(5)
        shot("06-rewards")
    }

    func test_07_redeem() {
        let app = launch()
        openInMore(app, "menu_redeem")
        // The reward catalogue is fetched when the screen opens.
        settle(10)
        shot("07-redeem")
    }

    // MARK: Helpers

    private func launch(realVisionAI: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-offline_model_opt_out", "YES", "-offline_model_prompt_dismissed", "YES", "-UITestSkipSplash"]
        if !realVisionAI { app.launchArguments += ["-UITestDisableVisionAI"] }
        app.launch()
        _ = app.buttons["moreMenuButton"].waitForExistence(timeout: 15)
        settle(2.5)
        return app
    }

    /// Any element with this identifier, whatever its type (iOS 26 menus don't always report items as buttons).
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// What the app showed, as text, for working out why a scene didn't reach its screen.
    private func diagnose(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = "diag-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func settle(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func go(_ app: XCUIApplication, to address: String) {
        let field = app.textFields["addressBarField"]
        guard field.waitForExistence(timeout: 8) else { return }
        field.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) { field.tap() }
        field.typeText(address)
        for key in ["Go", "go", "Return", "return"] where app.keyboards.buttons[key].exists {
            app.keyboards.buttons[key].tap()
            return
        }
        field.typeText("\n")
    }

    private func tapMore(_ app: XCUIApplication) {
        let more = element(app, "moreMenuButton")
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline && !(more.exists && !more.frame.isEmpty && more.frame.maxY > 0) { settle(0.3) }
        settle(0.6)
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Opens an item that lives in the overflow menu's "More" submenu.
    private func openInMore(_ app: XCUIApplication, _ identifier: String) {
        tapMore(app)
        let more = element(app, "menu_more")
        guard more.waitForExistence(timeout: 6) else { return diagnose(app, "menu-missing-\(identifier)-no-more") }
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let item = element(app, identifier)
        guard item.waitForExistence(timeout: 6) else { return diagnose(app, "menu-missing-\(identifier)") }
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
