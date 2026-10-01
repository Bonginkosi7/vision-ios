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

    /// Real History proof: navigate on a normal (non-private) tab, open the
    /// History sheet, and confirm the real visited URL shows up — exercises
    /// WebViewRepresentable's coordinator calling HistoryStore.record on a
    /// real didFinish callback, not a fabricated log entry.
    func test_historyRecordsRealNavigation() {
        let app = XCUIApplication()
        app.launch()

        let addressField = app.textFields["addressBarField"]
        XCTAssertTrue(addressField.waitForExistence(timeout: 5))
        navigate(app: app, addressField: addressField, to: "example.com")
        assertAddressBarEventuallyShows(addressField, "https://example.com/", in: self)

        app.buttons["historyButton"].tap()
        let historyURLText = app.staticTexts.matching(NSPredicate(format: "label == %@", "https://example.com/")).firstMatch
        XCTAssertTrue(historyURLText.waitForExistence(timeout: 5), "the real visited URL should show up in History")
    }

    /// Real Offline Library proof: navigate, tap Save Offline (a real
    /// WKWebView.createWebArchiveData call, see OfflineSaver.swift), wait
    /// for the real confirmation alert, then open the Offline Library,
    /// find the saved row, and tap it to reload the real saved
    /// .webarchive file — confirms the save round-trips to a real file on
    /// disk and back, not just a database row with nothing behind it.
    func test_offlineSaveAndReopen() {
        let app = XCUIApplication()
        app.launch()

        let addressField = app.textFields["addressBarField"]
        XCTAssertTrue(addressField.waitForExistence(timeout: 5))
        navigate(app: app, addressField: addressField, to: "example.com")
        assertAddressBarEventuallyShows(addressField, "https://example.com/", in: self)

        let saveButton = app.buttons["saveOfflineButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        let okButton = app.alerts["Save for Offline"].buttons["OK"]
        XCTAssertTrue(okButton.waitForExistence(timeout: 10), "expected a real save-confirmation alert")
        okButton.tap()

        app.buttons["offlineLibraryButton"].tap()
        let savedRowText = app.staticTexts.matching(NSPredicate(format: "label == %@", "Example Domain")).firstMatch
        XCTAssertTrue(savedRowText.waitForExistence(timeout: 5), "the saved page should show up in the Offline Library")
        savedRowText.tap()

        // Reopening loads the real local .webarchive file via
        // WKWebView.loadFileURL — the address bar should reflect a real
        // file:// URL once that navigation completes.
        let loadedPredicate = NSPredicate(format: "value BEGINSWITH %@", "file://")
        let loadedExpectation = XCTNSPredicateExpectation(predicate: loadedPredicate, object: addressField)
        XCTAssertEqual(XCTWaiter().wait(for: [loadedExpectation], timeout: 15), .completed, "reopening a saved page should load the real local file")
    }

    /// Real private-browsing proof: a new private tab shows the real
    /// "Private" indicator, and a page visited inside it is genuinely never
    /// written to History — exercises BrowserTab.isPrivate actually gating
    /// WebViewRepresentable's coordinator, not just a cosmetic label.
    func test_privateTabDoesNotRecordHistory() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["newPrivateTabButton"].waitForExistence(timeout: 5))
        app.buttons["newPrivateTabButton"].tap()
        XCTAssertTrue(app.staticTexts["privateIndicator"].waitForExistence(timeout: 5), "a new private tab should show the real Private indicator")

        let addressField = app.textFields["addressBarField"]
        navigate(app: app, addressField: addressField, to: "example.org")
        assertAddressBarEventuallyShows(addressField, "https://example.org/", in: self)

        app.buttons["historyButton"].tap()
        let privateURLText = app.staticTexts.matching(NSPredicate(format: "label == %@", "https://example.org/")).firstMatch
        XCTAssertFalse(privateURLText.exists, "a private tab's real navigation must never be written to History")
    }

    /// Real Keychain round-trip proof: save a real (fake-value) API key,
    /// confirm the status flips to Configured, clear it, confirm it flips
    /// back — exercises AiSettings/KeychainStore's actual
    /// SecItemAdd/SecItemCopyMatching/SecItemDelete calls, not a mocked
    /// store.
    func test_settingsSavesAndClearsAnAiKey() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        app.buttons["settingsButton"].tap()

        let status = app.staticTexts["anthropicStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("Not configured"), "expected a fresh install to start unconfigured, got: \(status.label)")

        let input = app.secureTextFields["anthropicKeyInput"]
        XCTAssertTrue(input.exists)
        input.tap()
        input.typeText("sk-ant-test-fake-key-for-ui-testing")
        app.buttons["anthropicSaveButton"].tap()

        let configuredPredicate = NSPredicate(format: "label CONTAINS %@", "Configured")
        let configuredExpectation = XCTNSPredicateExpectation(predicate: configuredPredicate, object: status)
        XCTAssertEqual(XCTWaiter().wait(for: [configuredExpectation], timeout: 5), .completed, "saving a real key should flip status to Configured")
        XCTAssertFalse(status.label.contains("Not configured"))

        app.buttons["anthropicClearButton"].tap()
        let clearedPredicate = NSPredicate(format: "label CONTAINS %@", "Not configured")
        let clearedExpectation = XCTNSPredicateExpectation(predicate: clearedPredicate, object: status)
        XCTAssertEqual(XCTWaiter().wait(for: [clearedExpectation], timeout: 5), .completed, "clearing the key should flip status back to Not configured")
    }

    /// Real behavioral proof the search-engine setting actually affects
    /// navigation, not just a UI toggle with nothing behind it: switch to
    /// DuckDuckGo, submit a plain search phrase (not a URL) from the
    /// address bar, and confirm the real resolved destination is a
    /// DuckDuckGo URL.
    func test_changingSearchEngineAffectsRealNavigation() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        app.buttons["settingsButton"].tap()

        let searchEnginePicker = app.buttons["searchEnginePicker"]
        XCTAssertTrue(searchEnginePicker.waitForExistence(timeout: 5))
        searchEnginePicker.tap()

        let duckDuckGoOption = app.buttons["DuckDuckGo"]
        XCTAssertTrue(duckDuckGoOption.waitForExistence(timeout: 5), "expected a real menu option for DuckDuckGo")
        duckDuckGoOption.tap()

        app.buttons["settingsDoneButton"].tap()

        let addressField = app.textFields["addressBarField"]
        XCTAssertTrue(addressField.waitForExistence(timeout: 5))
        navigate(app: app, addressField: addressField, to: "vision ios test query")

        let predicate = NSPredicate(format: "value BEGINSWITH %@", "https://duckduckgo.com/")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: addressField)
        let result = XCTWaiter().wait(for: [expectation], timeout: 15)
        if result != .completed {
            attachDiagnostics(app: app, name: "search-engine-not-duckduckgo")
        }
        XCTAssertEqual(
            result, .completed,
            "expected a search to resolve against DuckDuckGo after changing the setting, address bar read: \(addressField.value ?? "<nil>")"
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
