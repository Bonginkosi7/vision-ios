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

        openMenu(app, item: "menu_history")
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

        openMenu(app, item: "menu_saveOffline")

        let okButton = app.alerts["Save for Offline"].buttons["OK"]
        XCTAssertTrue(okButton.waitForExistence(timeout: 10), "expected a real save-confirmation alert")
        okButton.tap()

        openMenu(app, item: "menu_offlineLibrary")
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

        openMenu(app, item: "menu_newPrivateTab")
        XCTAssertTrue(app.staticTexts["privateIndicator"].waitForExistence(timeout: 5), "a new private tab should show the real Private indicator")

        let addressField = app.textFields["addressBarField"]
        navigate(app: app, addressField: addressField, to: "example.org")
        assertAddressBarEventuallyShows(addressField, "https://example.org/", in: self)

        openMenu(app, item: "menu_history")
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

        openMenu(app, item: "menu_settings")

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

        openMenu(app, item: "menu_settings")

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

    /// Real "no provider configured" proof: with no AI key saved, Rewrite
    /// Writer should show the real honest error RewriteWriter.swift
    /// returns — never a fabricated "rewritten" result standing in for
    /// one. No network call happens on this path at all.
    func test_rewriteWithNoProviderConfigured_showsHonestError() {
        let app = XCUIApplication()
        app.launch()

        openEducationMenu(app, item: "menu_rewrite")

        let input = app.textViews["rewriteInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("some real text to rewrite")

        app.buttons["rewriteAction_rewrite"].tap()

        let status = app.staticTexts["rewriteStatus"]
        let configuredPredicate = NSPredicate(format: "label CONTAINS %@", "No cloud AI provider is configured")
        let expectation = XCTNSPredicateExpectation(predicate: configuredPredicate, object: status)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed, "expected the real honest 'no provider configured' message")
    }

    /// Real end-to-end network proof, without needing a valid (billable)
    /// API key: save a real but fake Anthropic key via Settings (a real
    /// Keychain write, same path Phase 3 verified), trigger a rewrite, and
    /// confirm a real network-derived error comes back from the actual
    /// Anthropic API (a 401/403 for the invalid key) — proving
    /// CloudAIProvider's full real request pipeline fires, without ever
    /// calling it with real, paid credentials. Cleans the key up
    /// afterward so this doesn't affect other tests' assumptions about a
    /// fresh, unconfigured install.
    func test_rewriteWithInvalidKey_reachesRealAnthropicAPIAndShowsError() {
        let app = XCUIApplication()
        app.launch()

        openMenu(app, item: "menu_settings")
        let keyInput = app.secureTextFields["anthropicKeyInput"]
        XCTAssertTrue(keyInput.waitForExistence(timeout: 5))
        keyInput.tap()
        keyInput.typeText("sk-ant-invalid-fake-key-for-ui-testing")
        app.buttons["anthropicSaveButton"].tap()

        let configuredStatus = app.staticTexts["anthropicStatus"]
        let configuredExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "Configured"), object: configuredStatus)
        XCTAssertEqual(XCTWaiter().wait(for: [configuredExpectation], timeout: 5), .completed)
        app.buttons["settingsDoneButton"].tap()

        openEducationMenu(app, item: "menu_rewrite")
        let input = app.textViews["rewriteInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("some real text to rewrite")
        app.buttons["rewriteAction_rewrite"].tap()

        let status = app.staticTexts["rewriteStatus"]
        let failedPredicate = NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "API error", "failed")
        let failedExpectation = XCTNSPredicateExpectation(predicate: failedPredicate, object: status)
        let result = XCTWaiter().wait(for: [failedExpectation], timeout: 20)
        if result != .completed {
            attachDiagnostics(app: app, name: "rewrite-invalid-key-no-real-error")
        }
        XCTAssertEqual(result, .completed, "expected a real network-derived error from the actual Anthropic API, status read: \(status.label)")

        // Clean up so a later test (or re-run) doesn't see a key "already configured".
        app.buttons["rewriteDoneButton"].tap()
        openMenu(app, item: "menu_settings")
        app.buttons["anthropicClearButton"].tap()
        app.buttons["settingsDoneButton"].tap()
    }

    /// Real Focus Mode proof: add a real blocked domain, start a real
    /// session, confirm navigating to that domain is genuinely cancelled
    /// and FocusBlockedPage's local HTML shows instead (not a real
    /// example.com load), then end the session through the real
    /// WKScriptMessageHandler bridge (not Focus Mode's own Stop button) —
    /// specifically exercises the "focusBridge" wiring in
    /// WebViewRepresentable.swift, the one path no other test touches.
    func test_focusModeBlocksConfiguredDomainAndEndsViaTheRealBridge() {
        let app = XCUIApplication()
        app.launch()

        openMenu(app, item: "menu_focus")

        let domainField = app.textFields["addBlockedDomainField"]
        XCTAssertTrue(domainField.waitForExistence(timeout: 5))
        domainField.tap()
        domainField.typeText("example.com")
        app.buttons["addBlockedDomainButton"].tap()

        let blockedRow = app.otherElements["blockedDomainRow_example.com"]
        XCTAssertTrue(blockedRow.waitForExistence(timeout: 5), "the domain should show up in the real blocklist after adding it")

        app.buttons["focusPreset_15"].tap()
        app.buttons["startFocusSessionButton"].tap()

        let countdownLabel = app.staticTexts["focusCountdownLabel"]
        XCTAssertTrue(countdownLabel.waitForExistence(timeout: 5), "starting a session should show a real live countdown")

        app.navigationBars.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["focusActiveIndicator"].waitForExistence(timeout: 5), "an active session should show the real Focus indicator in the toolbar")

        let addressField = app.textFields["addressBarField"]
        navigate(app: app, addressField: addressField, to: "example.com")

        // Real blocking: the navigation is cancelled and replaced with
        // FocusBlockedPage's local HTML — this real page content is
        // rendered inside the WKWebView, bridged into the accessibility
        // tree by WebKit itself, not a native SwiftUI screen.
        let blockedPageHeading = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "is blocked right now")).firstMatch
        if !blockedPageHeading.waitForExistence(timeout: 10) {
            attachDiagnostics(app: app, name: "focus-mode-did-not-block")
        }
        XCTAssertTrue(blockedPageHeading.exists, "navigating to a blocked domain during an active session should show the real blocked page, not the real site")

        let endSessionButton = app.buttons["End session"]
        if !endSessionButton.waitForExistence(timeout: 5) {
            attachDiagnostics(app: app, name: "focus-bridge-end-session-button-not-found")
        }
        XCTAssertTrue(endSessionButton.exists)
        endSessionButton.tap()

        let indicatorGoneExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.staticTexts["focusActiveIndicator"]
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [indicatorGoneExpectation], timeout: 5), .completed,
            "tapping 'End session' on the blocked page should reach FocusManager.stopSession() through the real focusBridge message handler"
        )

        // Clean up the blocklist so this test is independent of rerun order.
        openMenu(app, item: "menu_focus")
        let removeButton = app.buttons["removeBlockedDomain_example.com"]
        if removeButton.waitForExistence(timeout: 5) {
            removeButton.tap()
        }
        app.navigationBars.buttons["Done"].tap()
    }

    /// Real Tasks proof: add a real task, confirm it's reachable under
    /// "Pending", complete it (one-way per TaskStore.complete's own
    /// guard), and confirm it moves to "Completed" and disappears from
    /// "Pending" — exercises TaskStore's real GRDB add/complete/list round
    /// trip, not a seeded or in-memory-only list.
    func test_tasksAddCompleteAndFilter() {
        let app = XCUIApplication()
        app.launch()

        openMenu(app, item: "menu_tasks")

        let field = app.textFields["newTaskField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let taskTitle = "UI test task \(UUID().uuidString.prefix(8))"
        field.tap()
        field.typeText(taskTitle)
        app.buttons["addTaskButton"].tap()

        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", taskTitle)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the real added task should show up in the list")

        app.buttons["Pending"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "a freshly added task should show under Pending")

        row.tap()

        app.buttons["Completed"].tap()
        if !row.waitForExistence(timeout: 5) {
            attachDiagnostics(app: app, name: "task-not-found-under-completed")
        }
        XCTAssertTrue(row.exists, "a completed task should show under Completed")

        app.buttons["Pending"].tap()
        XCTAssertFalse(row.waitForExistence(timeout: 3), "a completed task must not show under Pending (completion is one-way)")

        app.navigationBars.buttons["Done"].tap()
    }

    /// Real Advisor proof, scoped to what's honestly testable on a fresh
    /// launch: AdvisorLogic's 45-minute threshold genuinely cannot be
    /// reached inside a UI test's real wall-clock runtime, so this
    /// confirms the real "nothing to flag" path renders (not a suggestion
    /// card with nothing behind it), rather than fabricating a way to
    /// fast-forward WellbeingManager's real clock just to make a deeper
    /// test possible.
    ///
    /// A first real CI run found a genuine SwiftUI accessibility quirk
    /// here, the mirror image of Phase 1's bookmark-row merging bug: when
    /// `.accessibilityIdentifier` is applied to an HStack/VStack whose
    /// children are too complex to collapse into one element, SwiftUI
    /// doesn't synthesize a single `.other` container for it — it pushes
    /// the SAME identifier onto every leaf StaticText inside instead. The
    /// real captured accessibility-tree dump from that run confirmed this
    /// exactly (9 separate StaticTexts all carrying 'advisorQuickStatsRow',
    /// 4 all carrying 'advisorNoSuggestion'), so these query `staticTexts`,
    /// not `otherElements`.
    func test_advisorShowsNoNudgeOnAFreshLaunch() {
        let app = XCUIApplication()
        app.launch()

        openMenu(app, item: "menu_advisor")

        XCTAssertTrue(app.staticTexts["advisorQuickStatsRow"].waitForExistence(timeout: 5), "expected the real quick-stats row to render")
        XCTAssertTrue(app.staticTexts["advisorNoSuggestion"].waitForExistence(timeout: 5), "a fresh launch hasn't been continuously active for 45 real minutes, so no nudge should show")
        XCTAssertFalse(app.staticTexts["advisorSuggestionCard"].exists, "no suggestion card should render when AdvisorLogic genuinely returns nil")
        XCTAssertTrue(app.staticTexts["advisorWeekCard"].waitForExistence(timeout: 5), "expected the real This Week reward stats card to render (Phase 7 closes this Phase 6 trim)")

        app.navigationBars.buttons["Done"].tap()
    }

    /// Real Rewards proof: a genuine offline save should award a real
    /// OFFLINE_PREP point and show up as a real recent-activity row in
    /// RewardsView — not just a database row with nothing surfaced.
    /// Asserts on the specific saved-page note text rather than a point
    /// total, so this stays correct regardless of points already earned
    /// by other tests or earlier runs against the same persisted database.
    func test_savingOfflineAwardsARealRewardEvent() {
        let app = XCUIApplication()
        app.launch()

        let addressField = app.textFields["addressBarField"]
        navigate(app: app, addressField: addressField, to: "example.com")
        assertAddressBarEventuallyShows(addressField, "https://example.com/", in: self)

        openMenu(app, item: "menu_saveOffline")

        let okButton = app.alerts["Save for Offline"].buttons["OK"]
        XCTAssertTrue(okButton.waitForExistence(timeout: 10))
        okButton.tap()

        openMenu(app, item: "menu_rewards")
        let earnedNote = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Saved \"Example Domain\" for offline")).firstMatch
        if !earnedNote.waitForExistence(timeout: 5) {
            attachDiagnostics(app: app, name: "offline-save-reward-not-found")
        }
        XCTAssertTrue(earnedNote.exists, "a real offline save should show up as a real reward event in Rewards")

        app.navigationBars.buttons["Done"].tap()
    }

    /// Real Rewards proof for Tasks: completing a real task should award a
    /// real TASK_COMPLETED point and show up as a real recent-activity row.
    func test_completingATaskAwardsARealRewardEvent() {
        let app = XCUIApplication()
        app.launch()

        openMenu(app, item: "menu_tasks")
        let field = app.textFields["newTaskField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let taskTitle = "Reward UI test \(UUID().uuidString.prefix(8))"
        field.tap()
        field.typeText(taskTitle)
        app.buttons["addTaskButton"].tap()

        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", taskTitle)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.navigationBars.buttons["Done"].tap()

        openMenu(app, item: "menu_rewards")
        let earnedNote = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Completed \"\(taskTitle)\"")).firstMatch
        if !earnedNote.waitForExistence(timeout: 5) {
            attachDiagnostics(app: app, name: "task-completed-reward-not-found")
        }
        XCTAssertTrue(earnedNote.exists, "completing a real task should show up as a real reward event in Rewards")

        app.navigationBars.buttons["Done"].tap()
    }

    /// Real My Materials proof: process a real uploaded file (real text
    /// extraction via TxtExtractor against a real file on disk) and
    /// attempt real topic extraction with no AI provider configured,
    /// confirming the same honest "not configured" message
    /// test_rewriteWithNoProviderConfigured_showsHonestError already
    /// proved for Rewrite Writer — TopicExtractor routes through the
    /// exact same CloudAIProvider plumbing, not a parallel path.
    ///
    /// Driving iOS's own system file-picker sheet reliably from XCUITest
    /// is a known, real platform limitation (the Files app's UI, not this
    /// app's), so the upload step itself is skipped here in favor of a
    /// real fixture seeded at launch via `-UITestSeedMaterial` — see
    /// MainBrowserView.seedMaterialsFixtureIfRequested()'s own doc
    /// comment. Everything downstream of that real upload (processing,
    /// topic extraction, deletion) is still exercised for real.
    func test_processingAndExtractingTopicsForASeededMaterial() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSeedMaterial"]
        app.launch()

        openEducationMenu(app, item: "menu_materials")

        // A first real CI run found this row's container VStack carrying
        // its own .accessibilityIdentifier doesn't just leak onto plain
        // StaticText leaves (the Phase 6/7 quirk) — it can overwrite a
        // child BUTTON's own explicit identifier too (confirmed via a
        // real captured .xcresult dump: btnProcessDocument_* and
        // btnDeleteDocument_* both came back labeled with the row's own
        // identifier instead of their own). Fixed in MaterialsView.swift
        // by removing the container-level identifier entirely and giving
        // the title text its own (materialTitle_*).
        let row = app.staticTexts["materialTitle_ui-test-fixture"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the real seeded fixture should show up in My Materials")

        let processButton = app.buttons["btnProcessDocument_ui-test-fixture"]
        XCTAssertTrue(processButton.waitForExistence(timeout: 5), "expected a real Process button for an uploaded-but-unprocessed document")
        processButton.tap()

        let status = app.staticTexts["materialStatus_ui-test-fixture"]
        let processedPredicate = NSPredicate(format: "label CONTAINS %@", "Processed")
        let processedExpectation = XCTNSPredicateExpectation(predicate: processedPredicate, object: status)
        if XCTWaiter().wait(for: [processedExpectation], timeout: 20) != .completed {
            attachDiagnostics(app: app, name: "material-did-not-process")
        }
        XCTAssertTrue(status.label.contains("Processed"), "a real .txt fixture should process successfully, status read: \(status.label)")

        let topicsButton = app.buttons["btnTopics_ui-test-fixture"]
        XCTAssertTrue(topicsButton.waitForExistence(timeout: 5), "expected a real Topics button once the document is processed")
        topicsButton.tap()

        let topicsStatus = app.staticTexts["topicsStatus_ui-test-fixture"]
        let notConfiguredPredicate = NSPredicate(format: "label CONTAINS %@", "Cloud AI isn't configured")
        let notConfiguredExpectation = XCTNSPredicateExpectation(predicate: notConfiguredPredicate, object: topicsStatus)
        if XCTWaiter().wait(for: [notConfiguredExpectation], timeout: 10) != .completed {
            attachDiagnostics(app: app, name: "material-topics-no-honest-error")
        }
        XCTAssertTrue(topicsStatus.label.contains("Cloud AI isn't configured"), "expected the real honest 'not configured' message, got: \(topicsStatus.label)")

        // Clean up so a later run (or the same simulator's persisted
        // database) doesn't see the fixture as already present. Delete
        // lives behind a real swipe action (not a plain tap button —
        // see MaterialsView.documentRow's own doc comment for why), so
        // this swipes the row open before tapping it.
        row.swipeLeft()
        let deleteButton = app.buttons["btnDeleteDocument_ui-test-fixture"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()
        XCTAssertFalse(row.waitForExistence(timeout: 3), "deleting the fixture should remove its real row")

        app.navigationBars.buttons["Done"].tap()
    }

    /// Real Flashcards proof: process a real seeded fixture (reusing the
    /// same `-UITestSeedMaterial` fixture and processing flow Phase 8's
    /// test already proved), confirm the real document picker shows it
    /// once processed, then attempt real flashcard generation with no AI
    /// provider configured — the same honest "Cloud AI isn't configured"
    /// message Phase 5/8 already proved, since FlashcardGenerator routes
    /// through the identical CloudAIProvider/StructuredAI plumbing, not a
    /// parallel path. Confirms the real "nothing due"/"none yet" empty
    /// states render when generation genuinely produced no cards, rather
    /// than fabricating content.
    func test_generatingFlashcardsFromASeededMaterial() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSeedMaterial"]
        app.launch()

        openEducationMenu(app, item: "menu_materials")
        let materialRow = app.staticTexts["materialTitle_ui-test-fixture"]
        XCTAssertTrue(materialRow.waitForExistence(timeout: 5))

        let processButton = app.buttons["btnProcessDocument_ui-test-fixture"]
        XCTAssertTrue(processButton.waitForExistence(timeout: 5))
        processButton.tap()

        let materialStatus = app.staticTexts["materialStatus_ui-test-fixture"]
        let processedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Processed"), object: materialStatus
        )
        if XCTWaiter().wait(for: [processedExpectation], timeout: 20) != .completed {
            attachDiagnostics(app: app, name: "flashcards-material-did-not-process")
        }
        XCTAssertTrue(materialStatus.label.contains("Processed"))
        app.navigationBars.buttons["Done"].tap()

        openEducationMenu(app, item: "menu_flashcards")

        let generateButton = app.buttons["btnGenerateFlashcards"]
        if !generateButton.waitForExistence(timeout: 5) {
            attachDiagnostics(app: app, name: "flashcards-generate-button-not-found")
        }
        XCTAssertTrue(generateButton.exists, "expected a real Generate button once a processed document exists")
        generateButton.tap()

        let generateStatus = app.staticTexts["flashcardsGenerateStatus"]
        let notConfiguredExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Cloud AI isn't configured"), object: generateStatus
        )
        if XCTWaiter().wait(for: [notConfiguredExpectation], timeout: 10) != .completed {
            attachDiagnostics(app: app, name: "flashcards-generate-no-honest-error")
        }
        XCTAssertTrue(generateStatus.label.contains("Cloud AI isn't configured"), "expected the real honest 'not configured' message, got: \(generateStatus.label)")

        XCTAssertTrue(app.staticTexts["flashcardsNothingDue"].waitForExistence(timeout: 5), "no real flashcards exist yet, so nothing should be due")
        XCTAssertTrue(app.staticTexts["flashcardsNoneYet"].waitForExistence(timeout: 5), "a failed generation should leave a genuinely empty flashcard list, not fabricated cards")

        app.navigationBars.buttons["Done"].tap()

        // Clean up via Materials so a later run doesn't see the fixture
        // as already present.
        openEducationMenu(app, item: "menu_materials")
        materialRow.swipeLeft()
        let deleteButton = app.buttons["btnDeleteDocument_ui-test-fixture"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()
        app.navigationBars.buttons["Done"].tap()
    }

    /// Real Exams proof, in two halves:
    ///
    /// 1. A fully hand-authored MCQ exam, created, taken, and marked with
    ///    zero AI involvement — real local `ExamMarking` string comparison
    ///    end to end (choose the option known to be correct, submit, and
    ///    confirm the real score reads "100% correct"). Unlike Flashcards'
    ///    AI-only path, Create Exam needs no cloud key configured at all,
    ///    so this is a genuine full-credit real behavioral proof, not just
    ///    an honest-error path.
    /// 2. The same honest "Cloud AI isn't configured" proof already
    ///    established for Rewrite Writer/Topics/Flashcards, exercised here
    ///    through Generate Mock Test — confirming `ExamGenerator` routes
    ///    through the identical `CloudAIProvider`/`StructuredAI` plumbing.
    func test_takingAHandAuthoredExamAndGeneratingFromMaterial() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSeedMaterial"]
        app.launch()

        openEducationMenu(app, item: "menu_materials")
        let materialRow = app.staticTexts["materialTitle_ui-test-fixture"]
        XCTAssertTrue(materialRow.waitForExistence(timeout: 5))
        let processButton = app.buttons["btnProcessDocument_ui-test-fixture"]
        XCTAssertTrue(processButton.waitForExistence(timeout: 5))
        processButton.tap()
        let materialStatus = app.staticTexts["materialStatus_ui-test-fixture"]
        let processedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Processed"), object: materialStatus
        )
        if XCTWaiter().wait(for: [processedExpectation], timeout: 20) != .completed {
            attachDiagnostics(app: app, name: "exams-material-did-not-process")
        }
        XCTAssertTrue(materialStatus.label.contains("Processed"))
        app.navigationBars.buttons["Done"].tap()

        openEducationMenu(app, item: "menu_exams")

        // --- Half 1: hand-authored exam, taken and marked with no AI. ---
        let createButton = app.buttons["btnCreateExam"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let titleField = app.textFields["examTitleInput"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("UI Test Exam")

        app.textFields["questionPrompt_0"].tap()
        app.textFields["questionPrompt_0"].typeText("What is 2+2?")
        let optionTexts = ["3", "4", "5", "6"]
        for (index, text) in optionTexts.enumerated() {
            let field = app.textFields["mcqOption_0_\(index)"]
            field.tap()
            field.typeText(text)
        }
        app.buttons["mcqCorrect_0_1"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["btnSaveExam"].tap()

        let examRow = app.buttons.element(matching: NSPredicate(format: "identifier BEGINSWITH 'examRow_'"))
        XCTAssertTrue(examRow.waitForExistence(timeout: 5), "expected the just-saved exam to appear in the real list")
        examRow.tap()

        let correctOption = app.buttons.element(matching: NSPredicate(format: "identifier BEGINSWITH 'takingOption_' AND label == %@", "4"))
        XCTAssertTrue(correctOption.waitForExistence(timeout: 5))
        correctOption.tap()
        app.buttons["btnSubmitExam"].tap()

        let resultsScore = app.staticTexts["resultsScore"]
        let scoredExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "100% correct"), object: resultsScore)
        if XCTWaiter().wait(for: [scoredExpectation], timeout: 10) != .completed {
            attachDiagnostics(app: app, name: "exams-score-not-100-percent")
        }
        XCTAssertEqual(resultsScore.label, "100% correct", "a correctly-answered MCQ-only exam should be marked fully correct with no AI involved")
        app.navigationBars.buttons["Close"].tap()

        examRow.swipeLeft()
        let deleteExamButton = app.buttons.element(matching: NSPredicate(format: "identifier BEGINSWITH 'btnDeleteExam_'"))
        XCTAssertTrue(deleteExamButton.waitForExistence(timeout: 5))
        deleteExamButton.tap()

        // --- Half 2: AI-generated exam, honest "not configured" path. ---
        let generateEntryButton = app.buttons["btnGenerateExamEntry"]
        XCTAssertTrue(generateEntryButton.waitForExistence(timeout: 5))
        generateEntryButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let generateButton = app.buttons["btnGenerateExam"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 5), "expected a real Generate button once a processed document exists")
        generateButton.tap()

        let generateStatus = app.staticTexts["generateExamStatus"]
        let notConfiguredExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Cloud AI isn't configured"), object: generateStatus
        )
        if XCTWaiter().wait(for: [notConfiguredExpectation], timeout: 10) != .completed {
            attachDiagnostics(app: app, name: "exams-generate-no-honest-error")
        }
        XCTAssertTrue(generateStatus.label.contains("Cloud AI isn't configured"), "expected the real honest 'not configured' message, got: \(generateStatus.label)")
        app.navigationBars.buttons["Cancel"].tap()
        app.navigationBars.buttons["Done"].tap()

        // Clean up via Materials so a later run doesn't see the fixture as
        // already present.
        openEducationMenu(app, item: "menu_materials")
        materialRow.swipeLeft()
        let deleteMaterialButton = app.buttons["btnDeleteDocument_ui-test-fixture"]
        XCTAssertTrue(deleteMaterialButton.waitForExistence(timeout: 5))
        deleteMaterialButton.tap()
        app.navigationBars.buttons["Done"].tap()
    }

    /// Real AI Tutor proof — same honest "not configured" path already
    /// established for Rewrite Writer/Topics/Flashcards/Exams. Uses only
    /// the manual text-input path (type a question, tap Ask), not the
    /// suggestion chips: a real CI failure traced to the chip button
    /// living inside a horizontally-scrolling container, where a
    /// synthetic coordinate tap can be consumed by the ScrollView's own
    /// gesture recognizer without ever firing the Button's action — the
    /// tap reports success at the OS level, but `ask()` never runs. The
    /// manual input bar has no such container, so it isn't exposed to
    /// that risk, and exercises the exact same `ask()`/`TutorAI` code
    /// path. Asks twice to prove `TutorStore` persisted and reloaded the
    /// first real session's messages rather than losing them between
    /// turns, and confirms the real "No cloud AI configured" source
    /// label (no document is selected, so it must not claim to be
    /// grounded or general-AI).
    func test_askingTheAITutorWithNoCloudKeyConfigured() {
        let app = XCUIApplication()
        app.launch()

        openEducationMenu(app, item: "menu_tutor")

        let askInput = app.textFields["tutorAskInput"]
        XCTAssertTrue(askInput.waitForExistence(timeout: 5))
        askInput.tap()
        askInput.typeText("Quiz me")
        app.buttons["btnTutorAsk"].tap()

        let firstAnswer = app.staticTexts.element(matching: NSPredicate(format: "identifier BEGINSWITH 'tutorAnswer_'"))
        if !firstAnswer.waitForExistence(timeout: 10) {
            attachDiagnostics(app: app, name: "tutor-first-answer-missing")
        }
        XCTAssertTrue(firstAnswer.label.contains("I don't have a cloud AI provider configured"), "expected the real honest 'not configured' reply, got: \(firstAnswer.label)")

        let firstSource = app.staticTexts.element(matching: NSPredicate(format: "identifier BEGINSWITH 'tutorSource_'"))
        XCTAssertTrue(firstSource.waitForExistence(timeout: 5))
        XCTAssertEqual(firstSource.label, "No cloud AI configured", "no document is selected, so this must not claim to be grounded or general-AI")

        let questionCards = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'tutorQuestion_'"))
        XCTAssertTrue(waitForElementCount(questionCards, toEqual: 1), "expected exactly one exchange after the first ask")

        askInput.tap()
        askInput.typeText("What is gravity?")
        app.buttons["btnTutorAsk"].tap()

        if !waitForElementCount(questionCards, toEqual: 2, timeout: 10) {
            attachDiagnostics(app: app, name: "tutor-second-exchange-missing")
        }
        let answerCards = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'tutorAnswer_'"))
        XCTAssertTrue(waitForElementCount(answerCards, toEqual: 2, timeout: 10), "expected a real second answer after typing a second question and tapping Ask")

        app.navigationBars.buttons["Done"].tap()
    }

    /// Real Performance proof: with no cloud AI key configured in CI,
    /// real topic extraction can't actually run (same honest boundary
    /// Phase 8/9/10's own tests hit), so no document can ever have a real
    /// AI-identified topic in this environment — meaning the genuinely
    /// correct, honest behavior for Performance here is its own empty
    /// states, for both "All materials" and a specific real processed
    /// document, never fabricated mastery data. This confirms
    /// `PerformanceCalculator` really walks real topics (finding none)
    /// rather than showing something invented.
    func test_performanceShowsHonestEmptyStatesWithNoRealTopicData() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSeedMaterial"]
        app.launch()

        openEducationMenu(app, item: "menu_materials")
        let materialRow = app.staticTexts["materialTitle_ui-test-fixture"]
        XCTAssertTrue(materialRow.waitForExistence(timeout: 5))
        let processButton = app.buttons["btnProcessDocument_ui-test-fixture"]
        XCTAssertTrue(processButton.waitForExistence(timeout: 5))
        processButton.tap()
        let materialStatus = app.staticTexts["materialStatus_ui-test-fixture"]
        let processedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Processed"), object: materialStatus
        )
        if XCTWaiter().wait(for: [processedExpectation], timeout: 20) != .completed {
            attachDiagnostics(app: app, name: "performance-material-did-not-process")
        }
        XCTAssertTrue(materialStatus.label.contains("Processed"))
        app.navigationBars.buttons["Done"].tap()

        openEducationMenu(app, item: "menu_performance")

        XCTAssertTrue(app.staticTexts["performanceEmptyTopics"].waitForExistence(timeout: 5), "no real topic has ever been AI-extracted in this environment, so there must be nothing to show")
        XCTAssertTrue(app.staticTexts["performanceEmptyStrong"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["performanceEmptyWeak"].waitForExistence(timeout: 5))

        app.buttons["performanceDocumentPicker"].tap()
        let fixtureOption = app.buttons["UI Test Fixture"]
        XCTAssertTrue(fixtureOption.waitForExistence(timeout: 5), "expected a real menu option for the processed fixture document")
        fixtureOption.tap()

        XCTAssertTrue(app.staticTexts["performanceEmptyTopics"].waitForExistence(timeout: 5), "filtering to one real document with no real topics should still show the same honest empty state")

        app.navigationBars.buttons["Done"].tap()

        // Clean up via Materials so a later run doesn't see the fixture as
        // already present.
        openEducationMenu(app, item: "menu_materials")
        materialRow.swipeLeft()
        let deleteMaterialButton = app.buttons["btnDeleteDocument_ui-test-fixture"]
        XCTAssertTrue(deleteMaterialButton.waitForExistence(timeout: 5))
        deleteMaterialButton.tap()
        app.navigationBars.buttons["Done"].tap()
    }

    /// Real Study Plan proof: with no real AI-identified topic ever
    /// existing in this CI environment (same honest boundary Performance's
    /// own test hits), `StudyPlanGenerator` genuinely has nothing to
    /// schedule — confirming the real "No topics available..." empty
    /// state renders rather than a fabricated plan. Also exercises the
    /// real exam-date picker round-trip (pick a date, see the real
    /// countdown text, clear it back to the unset state) — a path that
    /// doesn't depend on any topic/AI data at all.
    func test_studyPlanShowsHonestEmptyPlanAndExamDateRoundTrips() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSeedMaterial"]
        app.launch()

        openEducationMenu(app, item: "menu_materials")
        let materialRow = app.staticTexts["materialTitle_ui-test-fixture"]
        XCTAssertTrue(materialRow.waitForExistence(timeout: 5))
        let processButton = app.buttons["btnProcessDocument_ui-test-fixture"]
        XCTAssertTrue(processButton.waitForExistence(timeout: 5))
        processButton.tap()
        let materialStatus = app.staticTexts["materialStatus_ui-test-fixture"]
        let processedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Processed"), object: materialStatus
        )
        if XCTWaiter().wait(for: [processedExpectation], timeout: 20) != .completed {
            attachDiagnostics(app: app, name: "studyplan-material-did-not-process")
        }
        XCTAssertTrue(materialStatus.label.contains("Processed"))
        app.navigationBars.buttons["Done"].tap()

        openEducationMenu(app, item: "menu_studyPlan")

        app.buttons["btnGenerateStudyPlan"].tap()
        XCTAssertTrue(app.staticTexts["studyPlanEmpty"].waitForExistence(timeout: 5), "no real topic has ever been AI-extracted in this environment, so there's nothing real to schedule")

        let dateButton = app.buttons["studyPlanExamDateInput"]
        XCTAssertTrue(dateButton.waitForExistence(timeout: 5))
        XCTAssertEqual(dateButton.label, "Exam date (optional)")
        dateButton.tap()

        let setDateButton = app.navigationBars.buttons["Set Date"]
        XCTAssertTrue(setDateButton.waitForExistence(timeout: 5), "expected the real date-picker sheet to open")
        setDateButton.tap()

        XCTAssertNotEqual(dateButton.label, "Exam date (optional)", "picking a real date should update the button's own label")

        app.buttons["btnGenerateStudyPlan"].tap()
        let countdown = app.staticTexts["studyPlanExamCountdown"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        XCTAssertTrue(countdown.label.contains("Exam in"), "expected a real countdown derived from the picked exam date, got: \(countdown.label)")

        app.buttons["btnClearExamDate"].tap()
        XCTAssertEqual(dateButton.label, "Exam date (optional)", "clearing the exam date should really reset it, not just hide it")

        app.navigationBars.buttons["Done"].tap()

        // Clean up via Materials so a later run doesn't see the fixture as
        // already present.
        openEducationMenu(app, item: "menu_materials")
        materialRow.swipeLeft()
        let deleteMaterialButton = app.buttons["btnDeleteDocument_ui-test-fixture"]
        XCTAssertTrue(deleteMaterialButton.waitForExistence(timeout: 5))
        deleteMaterialButton.tap()
        app.navigationBars.buttons["Done"].tap()
    }

    /// Real Paper Review proof: the same honest "Cloud AI isn't
    /// configured" path already established for Rewrite Writer/Topics/
    /// Flashcards/Exams, confirming `PaperReviewer` routes through the
    /// identical `CloudAIProvider`/`StructuredAI` plumbing against the
    /// same real seeded-and-processed fixture.
    func test_paperReviewWithNoCloudKeyConfigured() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSeedMaterial"]
        app.launch()

        openEducationMenu(app, item: "menu_materials")
        let materialRow = app.staticTexts["materialTitle_ui-test-fixture"]
        XCTAssertTrue(materialRow.waitForExistence(timeout: 5))
        let processButton = app.buttons["btnProcessDocument_ui-test-fixture"]
        XCTAssertTrue(processButton.waitForExistence(timeout: 5))
        processButton.tap()
        let materialStatus = app.staticTexts["materialStatus_ui-test-fixture"]
        let processedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Processed"), object: materialStatus
        )
        if XCTWaiter().wait(for: [processedExpectation], timeout: 20) != .completed {
            attachDiagnostics(app: app, name: "paper-review-material-did-not-process")
        }
        XCTAssertTrue(materialStatus.label.contains("Processed"))
        app.navigationBars.buttons["Done"].tap()

        openEducationMenu(app, item: "menu_paperReview")

        let reviewButton = app.buttons["btnReviewDocument"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 5), "expected a real Review button once a processed document exists")
        reviewButton.tap()

        let status = app.staticTexts["paperReviewStatus"]
        let notConfiguredExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Cloud AI isn't configured"), object: status
        )
        if XCTWaiter().wait(for: [notConfiguredExpectation], timeout: 10) != .completed {
            attachDiagnostics(app: app, name: "paper-review-no-honest-error")
        }
        XCTAssertTrue(status.label.contains("Cloud AI isn't configured"), "expected the real honest 'not configured' message, got: \(status.label)")

        app.navigationBars.buttons["Done"].tap()

        // Clean up via Materials so a later run doesn't see the fixture as
        // already present.
        openEducationMenu(app, item: "menu_materials")
        materialRow.swipeLeft()
        let deleteMaterialButton = app.buttons["btnDeleteDocument_ui-test-fixture"]
        XCTAssertTrue(deleteMaterialButton.waitForExistence(timeout: 5))
        deleteMaterialButton.tap()
        app.navigationBars.buttons["Done"].tap()
    }

    /// Real Help proof: a static but genuinely built-in documentation
    /// screen, confirmed by the real presence of its first and last real
    /// section cards (not screenshotted/guessed — the actual rendered
    /// accessibility tree).
    func test_helpShowsRealDocumentationSections() {
        let app = XCUIApplication()
        app.launch()

        openMenu(app, item: "menu_help")

        let firstCard = app.staticTexts["helpCardTitle_0_0"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5), "expected the real first Help card to render")
        XCTAssertEqual(firstCard.label, "Saving a page for offline")

        let lastCard = app.staticTexts["helpCardTitle_4_1"]
        XCTAssertTrue(lastCard.exists, "expected the real last Help card to render")
        XCTAssertEqual(lastCard.label, "Private Browsing")

        app.navigationBars.buttons["Done"].tap()
    }

    /// Real Ask VISION chat proof — same honest "not configured" path
    /// already established for every other AI feature, confirming:
    /// a fresh launch shows the real empty session list; starting a new
    /// chat, sending a real message, and getting the real honest reply
    /// with the real local category classification ("Learn", since the
    /// message matches that pattern); and that the real session this
    /// created now appears back in the session list with its real
    /// derived title. The input bar is a plain HStack (no scrolling
    /// container), matching the fix applied to the Tutor test's own
    /// manual-input path rather than any button living inside one.
    func test_askingVisionWithNoCloudKeyConfigured() {
        let app = XCUIApplication()
        app.launch()

        openMenu(app, item: "menu_askVision")

        XCTAssertTrue(app.staticTexts["askVisionEmptySessions"].waitForExistence(timeout: 5), "expected a real empty session list on a fresh launch")

        app.buttons["askVisionNewChatButton"].tap()

        let messageInput = app.textFields["chatMessageInput"]
        XCTAssertTrue(messageInput.waitForExistence(timeout: 5))
        messageInput.tap()
        messageInput.typeText("Explain how tides work")
        app.buttons["btnChatSend"].tap()

        let assistantMessage = app.staticTexts.element(matching: NSPredicate(format: "identifier BEGINSWITH 'chatAssistantMessage_'"))
        if !assistantMessage.waitForExistence(timeout: 10) {
            attachDiagnostics(app: app, name: "askvision-assistant-reply-missing")
        }
        XCTAssertTrue(assistantMessage.label.contains("no cloud AI is configured"), "expected the real honest 'not configured' reply, got: \(assistantMessage.label)")

        let categoryLabel = app.staticTexts.element(matching: NSPredicate(format: "identifier BEGINSWITH 'chatCategory_'"))
        XCTAssertTrue(categoryLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(categoryLabel.label, "Learn", "this message should classify as Learn")

        app.buttons["btnBackToChats"].tap()

        let sessionRow = app.buttons.element(matching: NSPredicate(format: "identifier BEGINSWITH 'askVisionSessionRow_'"))
        XCTAssertTrue(sessionRow.waitForExistence(timeout: 5), "expected the real session just created to appear back in the session list")
        XCTAssertEqual(sessionRow.label, "Explain how tides work")

        sessionRow.swipeLeft()
        let deleteButton = app.buttons.element(matching: NSPredicate(format: "identifier BEGINSWITH 'btnDeleteSession_'"))
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        app.navigationBars.buttons["Done"].tap()
    }

    /// Real VISION Ready proof: bookmark a real page, save it offline, and
    /// confirm the real percent/stats/category breakdown appear, straight
    /// from ReadinessLogic.compute over the real BookmarkStore/OfflineStore
    /// rows — not a fabricated 0%. Also exercises "Manage offline content"
    /// opening the real Offline Library on top of it.
    ///
    /// Deliberately doesn't assert an exact percent or a pristine starting
    /// empty state: every UI test in this suite shares one real app
    /// install/database for the whole run (confirmed the hard way — this
    /// test originally asserted "no bookmarks yet" first and failed for
    /// real, because `test_bookmarkingAPage_survivesAppTermination` runs
    /// alphabetically first and leaves a real, permanent bookmark behind),
    /// so other tests' real bookmarks/offline saves are genuinely present
    /// by the time this runs. Uses example.org specifically because no
    /// other test in this suite ever bookmarks or offline-saves it,
    /// keeping this test's own real before/after facts deterministic
    /// regardless of run order.
    func test_visionReadyShowsRealNumbersAfterBookmarkingAndSavingOffline() {
        let app = XCUIApplication()
        app.launch()

        let addressField = app.textFields["addressBarField"]
        XCTAssertTrue(addressField.waitForExistence(timeout: 5))
        navigate(app: app, addressField: addressField, to: "example.org")
        assertAddressBarEventuallyShows(addressField, "https://example.org/", in: self)

        let bookmarkButton = app.buttons["bookmarkButton"]
        XCTAssertTrue(bookmarkButton.waitForExistence(timeout: 5))
        XCTAssertEqual(bookmarkButton.label, "Add bookmark", "no other test in this suite ever bookmarks example.org")
        bookmarkButton.tap()
        let bookmarkedExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Remove bookmark"), object: bookmarkButton)
        XCTAssertEqual(XCTWaiter().wait(for: [bookmarkedExpectation], timeout: 5), .completed)

        openMenu(app, item: "menu_saveOffline")
        let okButton = app.alerts["Save for Offline"].buttons["OK"]
        XCTAssertTrue(okButton.waitForExistence(timeout: 10), "expected a real save-confirmation alert")
        okButton.tap()

        openMenu(app, item: "menu_visionReady")
        let percentText = app.staticTexts["visionReadyPercent"]
        if !percentText.waitForExistence(timeout: 5) {
            attachDiagnostics(app: app, name: "visionready-percent-missing")
        }
        XCTAssertTrue(percentText.exists, "at least our own real bookmark now exists, so this must be a real percent, never the empty state")
        XCTAssertTrue(app.staticTexts["visionReadyStatsSaved"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["visionReadyCategory_general"].waitForExistence(timeout: 5), "OfflineSaver's real default category is 'general', and our own save guarantees at least one")

        app.buttons["btnManageOfflineContent"].tap()
        let savedRowText = app.staticTexts.matching(NSPredicate(format: "label == %@", "Example Domain")).firstMatch
        XCTAssertTrue(savedRowText.waitForExistence(timeout: 5), "our real saved page (example.org, same placeholder title as example.com/.net) should show up in the real Offline Library opened from here")
        app.navigationBars.buttons["Done"].tap()

        app.navigationBars.buttons["Done"].tap()
    }

    // MARK: - Helpers

    /// Taps the real overflow ("⋮") menu button, then the named menu item
    /// — every action beyond back/forward/bookmark lives behind this one
    /// real SwiftUI `Menu` now (see MainBrowserView's own doc comment:
    /// a flat row of always-visible icon buttons genuinely overflowed the
    /// screen once Phase 7 added one icon too many, caught by this exact
    /// test suite failing for real in CI). One helper replaces what used
    /// to be a direct button tap at every call site below.
    ///
    /// Taps by raw coordinate rather than the semantic `.tap()`: a real
    /// captured `.xcresult` accessibility-tree dump (this project's
    /// established forensics technique) confirmed `moreMenuButton`'s
    /// frame is genuinely fully on-screen ({402.3, 76.7}-{422.0, 95.7}
    /// inside a 430pt-wide window) when `.tap()` still failed with
    /// `kAXErrorCannotComplete` trying to auto-scroll it into view first —
    /// not an off-screen layout bug, but XCUITest's default scroll-to-
    /// visible step genuinely tripping over SwiftUI `Menu`'s nested
    /// Button-inside-Button accessibility structure. A coordinate tap
    /// skips that failing step entirely; applied to the menu item too
    /// since it's built the same way.
    ///
    /// Three later attempts to "fix" an occasional CI failure here
    /// (`isHittable` + swipe-up; retry-if-item-still-exists; retry-if-
    /// moreMenuButton-still-exists) each made things *worse* — one run
    /// threw a new error class, another left a real downstream failure
    /// uncaught, and the last one failed almost the entire suite outright
    /// on a run that completed suspiciously fast, pointing to a real bug
    /// in the "fix" rather than runner slowness. None of those were
    /// reverted for lack of a theory — each was reverted because the
    /// next real CI run disproved it. This is back to exactly the plain,
    /// single-attempt version that was reliable across Phases 1–10: the
    /// rare genuine failures it still has are the same class of
    /// isolated, non-reproducing CI-runner-slowness flake this project
    /// has hit many times on completely unrelated tests, always
    /// resolved by a plain re-run with no code change — not something
    /// this helper should try to paper over with more logic.
    private func openMenu(_ app: XCUIApplication, item identifier: String) {
        let menuButton = app.buttons["moreMenuButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let menuItem = app.buttons[identifier]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), "expected menu item '\(identifier)' to exist in the overflow menu")
        menuItem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Same as `openMenu`, but for the real nested "Education" submenu
    /// (My Materials/Flashcards/Exams/AI Tutor/Performance/My Week/
    /// Rewrite Writer/Paper Review) — matches Android's own real
    /// `showOverflowMenu()` accordion group, added once the top-level
    /// popup grew too large to stay flat (see `MainBrowserView`'s own
    /// doc comment on `overflowMenu`).
    private func openEducationMenu(_ app: XCUIApplication, item identifier: String) {
        let menuButton = app.buttons["moreMenuButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let educationItem = app.buttons["menu_education"]
        XCTAssertTrue(educationItem.waitForExistence(timeout: 5), "expected the real Education submenu to exist in the overflow menu")
        educationItem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let menuItem = app.buttons[identifier]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), "expected menu item '\(identifier)' to exist in the Education submenu")
        menuItem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

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

    /// Waits for a live element query's count to reach an exact value —
    /// used where a UUID-keyed identifier (Tutor's per-exchange elements)
    /// means there's no single fixed identifier to `waitForExistence` on,
    /// only "how many of these exist now". `NSPredicate(block:)` is
    /// re-evaluated by the expectation machinery until it's true or the
    /// timeout elapses, same mechanism `XCTNSPredicateExpectation` already
    /// uses elsewhere in this file for label-content waits.
    private func waitForElementCount(_ query: XCUIElementQuery, toEqual expected: Int, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate { _, _ in query.count == expected }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
