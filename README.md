# VISION for iOS

Native Swift/SwiftUI iOS counterpart of the desktop Electron app ("Vision
browser") and the native Android port ("vision-android"). Built the same
way vision-android was: read the real source first, port an honest
equivalent, disclose anything that can't be honestly replicated rather than
fake it. See `/Users/user/.claude/plans/encapsulated-inventing-scone.md`
for the full architecture/roadmap this project follows.

Repo: https://github.com/Bonginkosi7/vision-ios

## Real, current status

**This machine still doesn't have Xcode installed** — only Command Line
Tools. That blocked all local verification, so **GitHub Actions** does the
verifying instead (`.github/workflows/ios.yml`, real Xcode on GitHub's own
macOS runners, triggered on every push to `main`). The acceptance bar for
every phase is the same: not "it compiles," but launched, driven in a real
booted Simulator, and behaviorally confirmed by `UITests/VisionIOSUITests.swift`.

**Phase 6** (Focus Mode, Tasks, Advisor) is done — first push's run
[`36858894373`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36858894373)
failed exactly one of 13 real UI tests: a genuine SwiftUI accessibility
quirk, the mirror image of Phase 1's bookmark-row merging bug (see below).
Found via the same real `.xcresult` Zstandard-blob forensics technique
used on Phase 1, fixed by querying what was actually there, and run
[`36861075136`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36861075136)
passed fully green — all 13 UI tests (including a real end-to-end Focus
Mode block, then unblock through the actual `focusBridge`
`WKScriptMessageHandler`) and all 43 VisionCore unit tests.

**Phase 1** (tab shell, address bar, New Tab, Bookmarks) is done — real
build [`36691346964`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36691346964)
confirmed the full test suite green, including force-terminating the app
and relaunching to prove a bookmark survived in a real, persisted
GRDB/SQLite database.

**Phase 5** (Rewrite Writer) is done — run
[`36855048304`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36855048304)
passed green on the first try, 43 tests total, zero failures, including
`test_rewriteWithInvalidKey_reachesRealAnthropicAPIAndShowsError`
genuinely reaching the live `api.anthropic.com` and getting a real
rejection back for the invalid key — see the Phase 5 section below for
exactly what is and isn't verified without a paid API key.

**Phase 4** (cloud AI provider layer) is done — run
[`36852551212`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36852551212)
passed green on the first try: all 9 new `CloudAIRequestBuilderTests`
plus all 8 existing UI tests (no regression from adding `CloudAIProvider.swift`
to the build). Its verification is deliberately narrower than every other
phase's — see the Phase 4 section below for why.

**Phase 3** (Settings & AI key storage) is done — run
[`36850625135`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36850625135)
passed green on the first try, all 8 real UI tests and all 21 VisionCore
unit tests, including the real Keychain save/clear round-trip and
confirming a DuckDuckGo search actually resolves against DuckDuckGo after
changing the setting.

**Phase 2** (History, Downloads, Offline Library, Private Browsing) is
done — run [`36846421828`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36846421828)
passed green on the first try (all 6 real UI tests, all 21 VisionCore unit
tests), no fix-and-repush cycle needed that time — applying Phase 1's own
lessons (real `@ObservedObject` reactivity, real keyboard taps, `List`-based
rows instead of a merge-prone VStack-of-Buttons) preemptively instead of
rediscovering them.

## Phase 6: Focus Mode & Productivity (Tasks, Advisor)

Direct port of `FocusDbHelper.kt`/`FocusManager.kt`/`FocusBlockedPage.kt`/
`FocusJsBridge.kt`/`FocusActivity.kt`, `TaskDbHelper.kt`/`TasksActivity.kt`,
and `WellbeingDbHelper.kt`/`WellbeingManager.kt`/`WellbeingActions.kt`/
`AdvisorLogic.kt`/`AdvisorActivity.kt` — reached via three new toolbar
buttons (timer / checklist / sparkles icons).

- **`Sources/VisionCore/FocusDomainMatcher.swift`** and
  **`AdvisorLogic.swift`** (pure, real-verified without Xcode via the
  standalone `swiftc` harness and `swift test`, same as every prior
  phase's VisionCore additions): domain-match logic (exact + subdomain +
  `www.`-normalization, direct port of `FocusDomainMatcherTest.kt`'s real
  cases) and the 45-minute continuous-session nudge threshold.
- **`App/FocusManager.swift`**: in-process session/timer state
  (`@MainActor` `ObservableObject` singleton, real `Timer.scheduledTimer`)
  — deliberately in-memory only, same tradeoff as Android: a session row
  left open by a process that died mid-session has no timer left to honor
  it, so `FocusStore.closeDanglingSessions()` cleans it up at next launch
  instead of adding a background-task mechanism this feature never had.
- **`App/FocusStore.swift`**: GRDB port of `FocusDbHelper.kt` — a
  user-authored blocklist (never a built-in "distracting sites" list this
  app has no honest basis to curate) plus session history.
- **`App/FocusBlockedPage.swift`** + the `WKScriptMessageHandler`
  conformance added to `WebViewRepresentable.Coordinator`: real Focus Mode
  blocking lives in a new `decidePolicyFor navigationAction` delegate
  method, which cancels the real navigation and loads this local HTML
  instead (a real client-side countdown against `FocusManager`'s real
  `endsAt`, not a static string). Its "End session" button posts to a
  real `WKScriptMessageHandler` named `"focusBridge"` — the direct
  WKWebView equivalent of Android's `FocusJsBridge.kt`
  `@JavascriptInterface`. Registering it required making `Coordinator`'s
  `tab` property `weak` (it was `let tab: BrowserTab` before): the content
  controller now holds a real strong reference back to `Coordinator`, and
  a strong `tab` reference there would have been a genuine retain cycle
  (`tab → webView → userContentController → Coordinator → tab`) leaking
  every tab forever, not a hypothetical.
- **`App/TaskStore.swift`**: GRDB port of `TaskDbHelper.kt` — binary
  open/completed only, no fabricated "in progress" state; completion is
  one-way (`complete(id:)` returns `nil` if already completed), same as
  the real Android/desktop data model.
- **`App/WellbeingManager.swift`** (in-process, intentionally
  in-memory-only, matching Android's own disclosed tradeoff) +
  **`WellbeingStore.swift`** (GRDB: real break events + real distinct
  site-visit tracking) + **`WellbeingActions.swift`** (real `takeBreak`,
  deliberately without the reward-eligibility hook `WellbeingActions.kt`
  has — `RewardEngine`/`RewardDbHelper` don't exist on iOS yet, a
  disclosed Phase 7 scope trim). Real site-visit recording was added
  alongside the existing history recording in `WebViewRepresentable`'s
  `didFinish`, gated the same way: real `http(s)` navigations only, never
  the local blocked-page HTML or an offline `file://` archive.
- **`FocusView.swift`** / **`TasksView.swift`** / **`AdvisorView.swift`**:
  duration-preset chips (15/25/45/60/90 min, `FocusActivity.kt`'s own
  `SESSION_PRESETS_MIN`) and a live countdown card; an add/filter/complete
  task list (`.pickerStyle(.segmented)`, not the push/pop `Form`-context
  style — same reliability choice Phase 3 made for Settings' pickers);
  real quick stats plus `AdvisorLogic`'s suggestion banner, wired to the
  same `takeBreak` action for both its "Take a break" and "5-min reset"
  buttons — confirmed from `AdvisorActivity.kt`'s own click handler that
  these two real actions are identical, not two features collapsed into
  one here.

### A real SwiftUI accessibility quirk, the mirror image of Phase 1's

Phase 1 found `.accessibilityElement`'s default *merging* could swallow a
child's own identifier into its parent's. Phase 6's first CI run found the
opposite failure mode: `.accessibilityIdentifier` applied to an
`HStack`/`tipCard` whose children are too complex for SwiftUI to collapse
into one element doesn't synthesize a container element at all — it pushes
the *same* identifier onto **every** leaf `StaticText` inside instead. The
real captured accessibility-tree dump (same Zstandard-blob `.xcresult`
forensics technique Phase 1 used) showed exactly that: 9 separate
`StaticText`s all carrying `'advisorQuickStatsRow'`, 4 all carrying
`'advisorNoSuggestion'` — none of them an `.other` container. Fixed by
querying `app.staticTexts[...]` instead of `app.otherElements[...]` in the
one affected test, matching what's actually real rather than restructuring
the (reusable, used-elsewhere) `DesignSystem` components to force a
different tree shape.

### Phase 6 UI tests

Three new cases in `VisionIOSUITests.swift`:
- `test_focusModeBlocksConfiguredDomainAndEndsViaTheRealBridge` — add a
  real blocked domain, start a real session, confirm navigating to it is
  genuinely cancelled and the real blocked page shows (rendered inside the
  WKWebView and bridged into the accessibility tree by WebKit itself, not
  a native screen), then end the session by tapping the blocked page's own
  "End session" button — the one path that specifically exercises the
  `focusBridge` `WKScriptMessageHandler` wiring, not Focus Mode's own Stop
  button.
- `test_tasksAddCompleteAndFilter` — add a real task, confirm it shows
  under Pending, complete it, confirm it moves to Completed and is gone
  from Pending (completion is genuinely one-way).
- `test_advisorShowsNoNudgeOnAFreshLaunch` — scoped to what's honestly
  testable on a fresh launch: `AdvisorLogic`'s 45-minute threshold cannot
  be reached inside a UI test's real wall-clock runtime, so this confirms
  the real "nothing to flag" path renders rather than fabricating a way to
  fast-forward `WellbeingManager`'s real clock just to test deeper.

`AppDatabase.swift`'s `v3_phase6` migration adds `focusBlockedDomain`,
`focusSession`, `task`, `wellbeingEvent`, `siteVisit` to the same shared
`vision.sqlite`.

## Phase 5: Rewrite Writer

Direct port of `RewriteActivity.kt`/`RewriteWriter.kt`/
`RewriteInstructions.kt` — the first real feature to call Phase 4's
`CloudAIProvider` layer, reached via a new "rewriteButton" (pencil icon)
in the secondary toolbar.

- **`Sources/VisionCore/RewriteInstructions.swift`** (pure, real-verified
  without Xcode): the 5 real actions (Rewrite/Improve grammar/Make
  simpler/Make more professional/Summarise) and their exact system-prompt
  instructions, verbatim ports of `RewriteInstructions.kt`.
- **`App/RewriteWriter.swift`**: tries configured cloud providers in the
  same real, specific order as `RewriteWriter.kt` — **OpenAI first, then
  Anthropic** (a different order from `ChatAiLogic.kt`'s Anthropic-first,
  preserved exactly rather than "normalized" to match the other one).
  Returns an honest `ok: false` with a real explanation when nothing is
  configured or every configured provider fails — never a fabricated
  "rewritten" result.
- **`RewriteView.swift`**: text input, the 5 action buttons, a status
  line, and a result card (copy / use-as-input) — direct port of
  `RewriteActivity.kt`'s UI.

### What Phase 5's CI verification actually proves (and doesn't)

This project still won't spend real money calling the live APIs with a
valid key from automated CI. Two real UI tests instead:
- `test_rewriteWithNoProviderConfigured_showsHonestError` — with no key
  saved, confirms the real "No cloud AI provider is configured" message
  (zero network calls on this path).
- `test_rewriteWithInvalidKey_reachesRealAnthropicAPIAndShowsError` —
  saves a real but fake Anthropic key via Settings (a real Keychain
  write), triggers a rewrite, and confirms a real network-derived error
  comes back from the **actual** `api.anthropic.com` (a 401/403 for the
  invalid key) — proving `CloudAIProvider`'s full real request pipeline
  genuinely fires end-to-end, without ever needing real, billable
  credentials. Cleans the key up afterward.

**What this does not prove**: that a *successful* rewrite with a real,
valid key actually produces a sensible result end-to-end through the UI.
That would need the user's own real API key — a decision for whoever has
one to make deliberately, not assumed or requested here.

## Phase 4: cloud AI provider layer

Direct port of `CloudAiProvider.kt` — infrastructure only, no UI yet (per
the build plan: Phase 5's Rewrite Writer is the first real feature to
consume it). Split deliberately across both halves of this repo:

- **`Sources/VisionCore/CloudAIRequestBuilder.swift`** (pure, no network,
  real-verified without Xcode): builds the exact real request (URL,
  headers, JSON body) for both providers, and parses their real response
  shapes (`content[].text` for Anthropic, `choices[0].message.content` for
  OpenAI) — separated out specifically so this logic gets the same local
  `swiftc`-harness + `swift test` verification as `AddressResolver`/
  `TabIndexing`, rather than being buried inside networking code that can
  only be checked in CI.
- **`App/CloudAIProvider.swift`**: the real `URLSession.shared.data(for:)`
  networking glue (async/await, no third-party HTTP library, matching
  `CloudAiProvider.kt`'s own minimal-dependency choice over
  `HttpURLConnection`), `AnthropicProvider`/`OpenAIProvider` reading keys
  from Phase 3's real `AiSettings`/Keychain store.

**Why this phase's CI verification is narrower than every other phase's:**
there's no UI yet for `UITests` to launch and drive, and this project
won't spend real money calling the live, paid Anthropic/OpenAI APIs from
automated CI with a throwaway key. So Phase 4's real verification is: (1)
`CloudAIRequestBuilder`'s request/response logic, genuinely tested via
`swift test` and (before that) a local standalone `swiftc` harness — same
discipline as `AddressResolver`/`TabIndexing`, all passing before this was
even pushed; (2) `xcodebuild build`/`test` confirming `CloudAIProvider.swift`
actually compiles and links against the real `URLSession`/Foundation APIs
in the real iOS SDK. What's genuinely **not** verified yet: `isAvailable()`
reading real Keychain state through this specific code path, and a live
`generate()` call succeeding end-to-end — deferred to Phase 5, once Rewrite
Writer gives this a real UI entry point a `UITest` can drive (and, for the
live-call path, realistically needs the user's own real API key rather
than a fake one — a decision for Phase 5, not assumed here).

## Phase 3: Settings & AI key storage

Direct port of the slice of `SettingsActivity.kt`/`AiSettings.kt`/
`VisionSettings.kt` this phase's scope covers — reached via a new
"settingsButton" (gear icon) added to the same secondary toolbar Phase 2
introduced.

- **`KeychainStore.swift`** — real Keychain Services wrapper
  (`SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete`), the direct iOS
  counterpart of Android's `EncryptedSharedPreferences` (AES-256, key
  material in the Android Keystore) — here, the Keychain's own secure
  storage plays the same role. Small enough (like `AiSettings.kt` itself)
  that wrapping the raw API directly is simpler and more honest than a
  dependency for it.
- **`AiSettings.swift`** — direct port of `AiSettings.kt`'s
  get/set/clear surface for the Anthropic and OpenAI keys, backed by
  `KeychainStore` instead of `EncryptedSharedPreferences`. Same reasoning
  for why this needs a real in-app UI at all: desktop's env-var keys have
  no meaning for a distributed binary.
- **`AppSettings.swift`** — direct port of `VisionSettings.kt`'s
  `SearchEngine`/`Theme` enums, scoped to exactly what this phase needs
  (not profile/weather/storage-limit/background-refresh — those land in
  later phases alongside the features that use them), backed by
  `UserDefaults` via `@AppStorage` so a change reactively redraws the UI
  (plain `UserDefaults` reads don't trigger that by themselves).
- **`SettingsView.swift`** — theme picker, search-engine picker, and the
  two AI key rows (save/clear/status — "Label — Configured"/"Not
  configured", same real UX pattern as `SettingsActivity.kt`'s
  `setUpAiKeyRow`). Profile, credentials, the offline on-device model,
  memory, and storage are later-phase scope.
- `MainBrowserView`'s previously-hardcoded Google search URL is now a real
  read from `AppSettings.searchEngine.queryUrl`, and `VisionIOSApp` reads
  the real theme setting instead of a hardcoded `.dark` — `nil` for
  "Follow system" is a deliberate real value (tells SwiftUI to inherit the
  OS's own appearance), not a missing case.

### Phase 3 UI tests

Two new cases, same bar as every phase before: launch it for real, drive
it, confirm the real behavior.
- `test_settingsSavesAndClearsAnAiKey` — save a (fake-value) key, confirm
  the status flips to Configured, clear it, confirm it flips back — a real
  Keychain round-trip, not a mocked store.
- `test_changingSearchEngineAffectsRealNavigation` — switch to DuckDuckGo
  in Settings, submit a plain search phrase from the address bar, confirm
  the real resolved destination is a DuckDuckGo URL — proves the setting
  actually affects live navigation, not just a UI toggle with nothing
  behind it.

## Phase 2: History, Downloads, Offline Library, Private Browsing

Direct ports of `HistoryActivity.kt`/`DownloadsActivity.kt`/
`OfflineLibraryActivity.kt`/`PrivateBrowsingActivity.kt`'s core surfaces,
reached from a new secondary toolbar row (History/Downloads/Offline
Library/Save Offline/New Private Tab) under the address bar — Phase 1 had
no overflow menu yet, so this phase doesn't invent one either, just direct
buttons.

- **History** (`HistoryStore.swift` + `HistoryView.swift`) — every real
  navigation on a non-private tab is recorded by `WebViewRepresentable`'s
  coordinator on `didFinish`; search/delete/clear are real, direct GRDB
  ports of `HistoryDbHelper.kt`. `frequentUrls` (desktop/Android's
  recommendations signal) isn't ported — nothing consumes it yet.
- **Downloads** (`DownloadStore.swift`, WKDownload handling in
  `WebViewRepresentable.swift`) — real downloads via `WKDownloadDelegate`
  (iOS's actual download mechanism): `decidePolicyFor navigationResponse`
  detects a `Content-Disposition: attachment` or an unrenderable MIME type
  and returns `.download`; the resulting `WKDownload` writes a real file
  under Application Support/Downloads. No `systemDownloadId` concept is
  ported — Android's version ties a row back to the OS's own
  `DownloadManager` service; iOS has no separate service to interoperate
  with, the `WKDownload` already *is* the real download.
- **Offline Library** (`OfflineStore.swift`, `OfflineSaver.swift`,
  `OfflineLibraryView.swift`) — the "Save Offline" toolbar button calls
  `WKWebView.createWebArchiveData(completionHandler:)`, Apple's own real
  page-snapshot API (the direct iOS counterpart of Android's
  `WebView.saveWebArchive()`), writes a real `.webarchive` file under
  Application Support/OfflineLibrary, and records its metadata in GRDB.
  Reopening a saved page loads that real file via `WKWebView.loadFileURL`.
  Smart Cache's refresh-tracking columns (etag/lastModified/contentHash/
  nextRefreshAt) and the recommendations table are **not** ported — there's
  no background refresh worker yet to use them, a disclosed scope trim
  matching `OfflineDbHelper.kt`'s own comment about Android having no
  predictive/auto-caching layer either.
- **Private Browsing** — no separate screen; `BrowserTab.isPrivate` + a
  "New Private Tab" button. A private tab's `WKWebView` is built with
  `WKWebsiteDataStore.nonPersistent()`, and the coordinator checks
  `!tab.isPrivate` before calling `HistoryStore.record`. This is actually a
  *stronger* real guarantee than Android's own private mode: Android's
  `PrivateBrowsingActivity.kt` needs an explicit `finishPrivateSession()`
  wipe because its WebView is disk-backed by default, where iOS's
  non-persistent data store never writes to disk in the first place —
  there's nothing to wipe, a real simplification, not a missing feature.

### AppDatabase migration `v2_phase2`

Adds `historyEntry`, `downloadRecord`, `offlineItem` tables to the same
shared `vision.sqlite` — see the migration's own comments in
`AppDatabase.swift` for exactly which Android columns were and weren't
ported and why.

### Phase 2 UI tests

Three new cases in `VisionIOSUITests.swift`, same "launch it for real and
drive it" bar as Phase 1:
- `test_historyRecordsRealNavigation` — navigate, open History, confirm the real URL is there.
- `test_offlineSaveAndReopen` — navigate, Save Offline, wait for the real confirmation alert, open the Offline Library, tap the saved row, confirm it reloads from a real local file (`file://` address bar value).
- `test_privateTabDoesNotRecordHistory` — new private tab shows the real "Private" indicator, navigates to a distinct real URL, and that URL is confirmed **absent** from History afterward.

## Seven real bugs Phase 1's CI loop found and fixed

Documented here rather than squashed away, matching this whole project's
convention of keeping a real debugging trail. The first three were CI/tooling
issues; the rest were genuine app bugs the UI tests actually caught:

1. **XcodeGen generated a project in a newer format than the runner's
   default Xcode could read** (`"future Xcode project file format (77)"`).
   Fixed by explicitly selecting the newest Xcode installed on the runner.
2. **A greedy `sed` pattern picked up a simulator's UDID along with its
   name** (two parenthetical groups on one `simctl` line). Fixed by
   trimming from the first `" ("` onward instead of capturing up to it.
3. **`{name:X, OS:latest}` didn't match** — this runner's "latest" runtime
   isn't paired with every device silhouette. Fixed by targeting one
   confirmed simulator directly by UDID.
4. **`MainBrowserView` never observed `BrowserTab`'s own `@Published`
   changes** — `content`'s `if tab.isNewTab {...}` read a `@Published`
   property off a plain local `let`, which SwiftUI doesn't track the way it
   tracks `@StateObject`/`@ObservedObject`-wrapped properties declared on a
   View struct. The view never switched from `NewTabView` to the real
   `WebViewRepresentable` when navigation started. Fixed by wrapping the
   active tab in a dedicated `ActiveTabContent` view with a real
   `@ObservedObject var tab: BrowserTab`.
5. **Embedding `"\n"` in `typeText` didn't reliably submit a SwiftUI
   `TextField`** — a known, real XCUITest gotcha. Fixed by tapping the
   actual on-screen Return/Go key instead.
6. **Tests asserted `"https://example.com"` but the real value is
   `"https://example.com/"`** — WKWebView canonicalizes a bare-domain root
   request to include the trailing slash. Found by downloading the failed
   run's `.xcresult` artifact and decompressing its Zstandard-compressed
   data blobs by hand (no `xcresulttool` locally either — also Xcode-only —
   so this needed a quick `pip install zstandard` and manual inspection) to
   read the actual captured element value instead of guessing again.
7. **A bookmark row's own accessibility identifier was silently merged
   away** — SwiftUI's default accessibility-element merging collapsed each
   row's `Button` (and its `"bookmarkRow_<url>"` identifier) into the outer
   card container, so the test's query legitimately found nothing even
   though the bookmark had genuinely persisted correctly (confirmed by
   reading the actual captured accessibility-tree dump: a single merged
   `Button`, identifier `'bookmarksList'`, label `'🔖, Example Domain'`).
   Fixed with `.accessibilityElement(children: .contain)`, the real,
   documented API for keeping a container's children independently
   accessible instead of flattened into one element.

For #6 and #7: when a plain screenshot attachment wasn't enough to diagnose
without guessing, the UI tests were extended with a reusable
`attachDiagnostics()` helper that captures both a screenshot and the full
`app.debugDescription` accessibility tree (plain text) on failure — reused
as-is for Phase 2's new tests too.

## What was verified locally, without Xcode, before CI existed

Bare `swiftc` works here even though Xcode itself doesn't. Before GitHub
Actions was set up, `Sources/VisionCore`'s pure-logic files —
`AddressResolver.swift`/`TabIndexing.swift` (Phase 1), `CloudAIRequestBuilder.swift`
(Phase 4), and `RewriteInstructions.swift` (Phase 5) — direct ports of the
matching `.kt` files — were type-checked directly and actually compiled
and run against real test cases via a standalone `main.swift` harness
(bypassing SPM's own broken toolchain on this machine — `swift build`/
`swift test` fail here with `xcrun: error: unable to lookup item
'PlatformPath'`): 21 cases for Phase 1's files, 17 more for Phase 4's, 9
more for Phase 5's. All passed, every time, before any of it was pushed.
Superseded now by real `swift test` CI runs, but kept as a record that
even the "no Xcode at all" state had a genuine verification path, not a
guess.

The one disclosed real behavioral difference found along the way:
`resolveDestination` percent-encodes a space as `%20` (Swift's
`addingPercentEncoding`) where the Kotlin/Java port uses `+`
(`URLEncoder`) — different literal bytes, identical resolved destination
for every real search engine. Noted in `AddressResolver.swift`'s doc
comment.

## File-by-file

**`App/`** (SwiftUI + UIKit + WebKit + GRDB, real iOS target):
- `VisionIOSApp.swift` — `@main` entry point
- `MainBrowserView.swift` — address bar, secondary toolbar, hosts the active tab via `ActiveTabContent`
- `WebViewRepresentable.swift` — `UIViewRepresentable` wrapping one `WKWebView` per tab; real history recording + real `WKDownloadDelegate` handling
- `BrowserTab.swift` — mirrors `Tab.kt` (id, title, url, isNewTab, isPrivate)
- `TabManager.swift` — mirrors `MainActivity.kt`'s `tabs`/`activeTabIndex` + create/switch/close/navigate/openOfflineFile, delegates close-index math to `VisionCore.TabIndexing`
- `AppDatabase.swift` — GRDB `DatabaseQueue` + migrator (`v1_bookmarks`, `v2_phase2`, `v3_phase6`)
- `BookmarkStore.swift` / `HistoryStore.swift` / `DownloadStore.swift` / `OfflineStore.swift` — GRDB ports of the matching `*DbHelper.kt`
- `OfflineSaver.swift` — real `createWebArchiveData` capture + file write
- `KeychainStore.swift` / `AiSettings.swift` — real Keychain-backed AI key storage, port of `AiSettings.kt`
- `AppSettings.swift` — `UserDefaults`/`@AppStorage`-backed theme + search engine, port of `VisionSettings.kt`'s Phase 3 slice
- `CloudAIProvider.swift` — real `URLSession` networking for the two cloud AI providers, port of `CloudAiProvider.kt`
- `RewriteWriter.swift` — real OpenAI-then-Anthropic rewrite orchestration, port of `RewriteWriter.kt`
- `FocusManager.swift` / `FocusStore.swift` / `FocusBlockedPage.swift` — real Focus Mode session timer, GRDB blocklist/session history, and the local blocked-page HTML, port of `FocusManager.kt`/`FocusDbHelper.kt`/`FocusBlockedPage.kt`
- `TaskStore.swift` — GRDB port of `TaskDbHelper.kt`
- `WellbeingManager.swift` / `WellbeingStore.swift` / `WellbeingActions.swift` — in-process tracking + GRDB break/site-visit log, port of `WellbeingManager.kt`/`WellbeingDbHelper.kt`/`WellbeingActions.kt`
- `FaviconLoader.swift` — real `google.com/s2/favicons` fetch + in-memory cache, used by Focus Mode's blocklist rows
- `NewTabView.swift` / `HistoryView.swift` / `DownloadsView.swift` / `OfflineLibraryView.swift` / `SettingsView.swift` / `RewriteView.swift` / `FocusView.swift` / `TasksView.swift` / `AdvisorView.swift` — real list/empty-state/settings/rewrite/focus/tasks/advisor screens
- `DesignSystem.swift` — same component list and color tokens as `DesignSystem.kt`, ported to `@ViewBuilder` functions; drawable XML collapses into inline SwiftUI modifiers (disclosed simplification, noted in-file)

**`UITests/`** — `VisionIOSUITests.swift`, the real behavioral verification described above.

`project.yml` (XcodeGen spec) generates the actual `.xcodeproj` (app target
+ `VisionIOSUITests` target + a `VisionIOS` scheme wiring both) in CI —
there's no hand-crafted `.pbxproj` in this repo, it's regenerated fresh
every run.

## Explicitly NOT built yet (disclosed scope trims, not oversights)

Profile/credentials/offline-AI-model/memory/storage settings, on-device
local model fallback, the Ask VISION chat, every remaining education
screen (Study Materials, Flashcards, Exams, Tutor, Performance, Study
Plan, Paper Review), Rewards/Redeem, VISION Ready, Help, and the overflow
menu. Also, within what Phase 6 did build: `WellbeingActions.takeBreak`
has no reward-eligibility hook (`RewardEngine`/`RewardDbHelper` don't
exist on iOS yet), and `TaskStore.complete`'s one-way guard exists
specifically so a task can't be farmed for reward points once that
exists either. Sequencing for all of these is in the build plan's Phase
7–12 roadmap.

## Next steps

Phase 7: Rewards + Redeem — gated behind Phase 6 since real earning
actions (offline save, a completed focus session, a completed task) need
to exist first, which they now do. Redeem's Firestore sync should mirror
Android's plain REST client choice (`FirestoreRestClient.kt`) over
pulling in the full Firebase SDK.

**If local Xcode ever exists on this machine**: `xcodegen generate`, open
`VisionIOS.xcodeproj`, and everything here still works locally too — CI
was the necessary path given no Xcode locally, not a permanent substitute
for it.
