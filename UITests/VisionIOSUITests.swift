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

        openMenu(app, item: "menu_rewrite")

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

        openMenu(app, item: "menu_rewrite")
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

        openMenu(app, item: "menu_materials")

        // materialRow_* is applied to a VStack whose children are too
        // complex for SwiftUI to collapse into one accessibility element
        // — the same real quirk Phase 6/7 found (the identifier lands on
        // every leaf StaticText inside instead of a single `.other`), so
        // this queries staticTexts, not otherElements.
        let row = app.staticTexts["materialRow_ui-test-fixture"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the real seeded fixture should show up in My Materials")

        app.buttons["btnProcessDocument_ui-test-fixture"].tap()

        let status = app.staticTexts["materialStatus_ui-test-fixture"]
        let processedPredicate = NSPredicate(format: "label CONTAINS %@", "Processed")
        let processedExpectation = XCTNSPredicateExpectation(predicate: processedPredicate, object: status)
        if XCTWaiter().wait(for: [processedExpectation], timeout: 10) != .completed {
            attachDiagnostics(app: app, name: "material-did-not-process")
        }
        XCTAssertTrue(status.label.contains("Processed"), "a real .txt fixture should process successfully, status read: \(status.label)")

        app.buttons["btnTopics_ui-test-fixture"].tap()

        let topicsStatus = app.staticTexts["topicsStatus_ui-test-fixture"]
        let notConfiguredPredicate = NSPredicate(format: "label CONTAINS %@", "Cloud AI isn't configured")
        let notConfiguredExpectation = XCTNSPredicateExpectation(predicate: notConfiguredPredicate, object: topicsStatus)
        if XCTWaiter().wait(for: [notConfiguredExpectation], timeout: 5) != .completed {
            attachDiagnostics(app: app, name: "material-topics-no-honest-error")
        }
        XCTAssertTrue(topicsStatus.label.contains("Cloud AI isn't configured"), "expected the real honest 'not configured' message, got: \(topicsStatus.label)")

        // Clean up so a later run (or the same simulator's persisted
        // database) doesn't see the fixture as already present.
        app.buttons["btnDeleteDocument_ui-test-fixture"].tap()
        XCTAssertFalse(row.waitForExistence(timeout: 3), "deleting the fixture should remove its real row")

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
    private func openMenu(_ app: XCUIApplication, item identifier: String) {
        let menuButton = app.buttons["moreMenuButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let menuItem = app.buttons[identifier]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), "expected menu item '\(identifier)' to exist in the overflow menu")
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
}
