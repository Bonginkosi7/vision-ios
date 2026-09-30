import XCTest

/// Real behavioral verification, launched and driven in an actual booted
/// simulator — this is what a green `xcodebuild build` alone can't prove
/// (that the code is *valid*, not that it *behaves* correctly). Each test
/// is written to be independent of execution order: no test assumes a
/// globally empty bookmark store, since XCTest doesn't guarantee run order
/// and these tests genuinely do persist real data across launches.
final class VisionIOSUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Structural smoke test: the address bar and tab count render on a
    /// fresh launch, and the New Tab page is showing (not a blank WebView,
    /// not a crash).
    func test_appLaunches_showsAddressBarAndNewTab() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.textFields["addressBarField"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["tabCountLabel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["tabCountLabel"].label, "1")
    }

    /// Real end-to-end navigation: type a real address, submit it, and
    /// confirm the address bar reflects the real resolved+loaded URL —
    /// exercises AddressResolver, TabManager, WKWebView, and
    /// WebViewRepresentable's coordinator together, not in isolation.
    func test_typingARealAddress_navigatesAndUpdatesTheAddressBar() {
        let app = XCUIApplication()
        app.launch()

        let addressField = app.textFields["addressBarField"]
        XCTAssertTrue(addressField.waitForExistence(timeout: 5))
        navigate(app: app, addressField: addressField, to: "example.com")

        // A real fact confirmed from an actual failed run's captured
        // element dump, not assumed: WKWebView canonicalizes a bare-domain
        // root request to include the trailing slash ("https://example.com/"),
        // so that's the real value to expect here, not the string as typed.
        assertAddressBarEventuallyShows(addressField, "https://example.com/", in: self)
    }

    /// The real persistence proof this phase's verification plan calls
    /// for: navigate, bookmark, terminate the process, relaunch, and
    /// confirm the bookmark is still there — i.e. it actually reached
    /// GRDB/SQLite and survived a real process death, not just an
    /// in-memory flag.
    func test_bookmarkingAPage_survivesAppTermination() {
        // Real value confirmed from a captured element dump on a prior
        // failed run: WKWebView canonicalizes example.com's root path to
        // include a trailing slash, and BrowserTab.url is set directly from
        // webView.url?.absoluteString — so that's the real URL that ends
        // up both in the address bar and in the bookmark row's identifier.
        let testURL = "https://example.com/"
        let bookmarkRowIdentifier = "bookmarkRow_\(testURL)"

        let app = XCUIApplication()
        app.launch()

        let addressField = app.textFields["addressBarField"]
        XCTAssertTrue(addressField.waitForExistence(timeout: 5))
        navigate(app: app, addressField: addressField, to: "example.com")
        assertAddressBarEventuallyShows(addressField, testURL, in: self)

        let bookmarkButton = app.buttons["bookmarkButton"]
        XCTAssertTrue(bookmarkButton.waitForExistence(timeout: 5))
        XCTAssertEqual(bookmarkButton.label, "Add bookmark", "should start unbookmarked for this fresh navigation")
        bookmarkButton.tap()

        let addedPredicate = NSPredicate(format: "label == %@", "Remove bookmark")
        let addedExpectation = XCTNSPredicateExpectation(predicate: addedPredicate, object: bookmarkButton)
        XCTAssertEqual(XCTWaiter().wait(for: [addedExpectation], timeout: 5), .completed, "tapping the star should flip it to bookmarked")

        // Real process termination, not just backgrounding — this is what
        // actually exercises whether the write reached disk.
        app.terminate()

        let relaunched = XCUIApplication()
        relaunched.launch()

        // A fresh launch starts on a new tab, so the New Tab page (and its
        // real bookmarks row, sourced from BookmarkStore.list()) should be
        // showing again.
        let bookmarkRow = relaunched.buttons[bookmarkRowIdentifier]
        if !bookmarkRow.waitForExistence(timeout: 8) {
            attachDiagnostics(app: relaunched, name: "bookmark-not-found-after-relaunch")
        }
        XCTAssertTrue(
            bookmarkRow.exists,
            "the bookmark saved before termination should be read back from the real, persisted database on relaunch " +
            "(empty-state showing instead: \(relaunched.otherElements["emptyBookmarksState"].exists))"
        )
    }

    // MARK: - Helpers

    /// Types into the address bar and submits it. A first CI run revealed a
    /// real, well-documented XCUITest gotcha: embedding "\n" inside
    /// `typeText` doesn't reliably trigger a SwiftUI TextField's submit
    /// action the way an explicit on-screen "Return"/"Go" key tap does —
    /// so this taps the real keyboard key instead of relying on an escape
    /// character, with a fallback to the embedded "\n" only if no such key
    /// is found (keeps this from silently doing nothing on an unexpected
    /// keyboard layout).
    private func navigate(app: XCUIApplication, addressField: XCUIElement, to text: String) {
        addressField.tap()
        addressField.typeText(text)

        let returnKey = app.keyboards.buttons["Return"]
        let goKey = app.keyboards.buttons["Go"]
        if returnKey.waitForExistence(timeout: 3) {
            returnKey.tap()
        } else if goKey.exists {
            goKey.tap()
        } else {
            addressField.typeText("\n")
        }
    }

    /// Waits for the address bar to show the expected resolved URL, and on
    /// failure attaches a screenshot plus the field's actual value to the
    /// test's own failure output — real diagnostics for the next run
    /// instead of a bare timeout with no further information.
    private func assertAddressBarEventuallyShows(_ addressField: XCUIElement, _ expected: String, in testCase: XCTestCase) {
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: addressField)
        let result = XCTWaiter().wait(for: [expectation], timeout: 15)

        if result != .completed {
            attachDiagnostics(app: XCUIApplication(), name: "address-bar-timeout")
        }

        XCTAssertEqual(
            result, .completed,
            "expected address bar to show \"\(expected)\" but it read \"\(addressField.value ?? "<nil>")\" after 15s"
        )
    }

    /// Attaches a screenshot AND the full real accessibility tree
    /// (`app.debugDescription`, plain text — no image/video decoding needed
    /// to read it back afterward) to the test's failure output. A first CI
    /// failure with only a screenshot attached turned out to need more than
    /// that to diagnose without guessing, so this captures both up front.
    private func attachDiagnostics(app: XCUIApplication, name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let screenshotAttachment = XCTAttachment(screenshot: screenshot)
        screenshotAttachment.name = "\(name)-screenshot"
        screenshotAttachment.lifetime = .keepAlways
        add(screenshotAttachment)

        let hierarchyAttachment = XCTAttachment(string: app.debugDescription)
        hierarchyAttachment.name = "\(name)-hierarchy"
        hierarchyAttachment.lifetime = .keepAlways
        add(hierarchyAttachment)
    }
}
