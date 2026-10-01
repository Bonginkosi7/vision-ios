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

**Phase 1** (tab shell, address bar, New Tab, Bookmarks) is done — real
build [`36691346964`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36691346964)
confirmed the full test suite green, including force-terminating the app
and relaunching to prove a bookmark survived in a real, persisted
GRDB/SQLite database.

**Phase 4** (cloud AI provider layer) is implemented and pushed; its CI run
is the next thing to watch. Note its verification is deliberately narrower
than every phase before it — see the Phase 4 section below for why.

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
`AddressResolver.swift`/`TabIndexing.swift` (Phase 1, direct ports of
`AddressResolver.kt`/`TabIndexing.kt`) and `CloudAIRequestBuilder.swift`
(Phase 4) — were type-checked directly and actually compiled and run
against real test cases via a standalone `main.swift` harness (bypassing
SPM's own broken toolchain on this machine — `swift build`/`swift test`
fail here with `xcrun: error: unable to lookup item 'PlatformPath'`): 21
cases for Phase 1's files, 17 more for Phase 4's. All passed, every time,
before any of it was pushed. Superseded now by real `swift test` CI runs,
but kept as a record that even the "no Xcode at all" state had a genuine
verification path, not a guess.

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
- `AppDatabase.swift` — GRDB `DatabaseQueue` + migrator (`v1_bookmarks`, `v2_phase2`)
- `BookmarkStore.swift` / `HistoryStore.swift` / `DownloadStore.swift` / `OfflineStore.swift` — GRDB ports of the matching `*DbHelper.kt`
- `OfflineSaver.swift` — real `createWebArchiveData` capture + file write
- `KeychainStore.swift` / `AiSettings.swift` — real Keychain-backed AI key storage, port of `AiSettings.kt`
- `AppSettings.swift` — `UserDefaults`/`@AppStorage`-backed theme + search engine, port of `VisionSettings.kt`'s Phase 3 slice
- `CloudAIProvider.swift` — real `URLSession` networking for the two cloud AI providers, port of `CloudAiProvider.kt`; no UI consumer yet (Phase 5)
- `NewTabView.swift` / `HistoryView.swift` / `DownloadsView.swift` / `OfflineLibraryView.swift` / `SettingsView.swift` — real list/empty-state/settings screens
- `DesignSystem.swift` — same component list and color tokens as `DesignSystem.kt`, ported to `@ViewBuilder` functions; drawable XML collapses into inline SwiftUI modifiers (disclosed simplification, noted in-file)

**`UITests/`** — `VisionIOSUITests.swift`, the real behavioral verification described above.

`project.yml` (XcodeGen spec) generates the actual `.xcodeproj` (app target
+ `VisionIOSUITests` target + a `VisionIOS` scheme wiring both) in CI —
there's no hand-crafted `.pbxproj` in this repo, it's regenerated fresh
every run.

## Explicitly NOT built yet (disclosed scope trims, not oversights)

Focus Mode, Profile/credentials/offline-AI-model/memory/storage settings,
any real UI that actually calls the cloud AI provider layer (it exists and
compiles now, nothing calls out with it yet), on-device local model
fallback, the Ask VISION chat, every education screen (Study Materials,
Flashcards, Exams, Tutor, Performance, Study Plan, Paper Review,
Rewrite), Rewards/Redeem, Advisor, VISION Ready, Help, and the overflow
menu. Sequencing for all of these is in the build plan's Phase 5–12
roadmap.

## Next steps

1. Watch Phase 4's CI run; iterate on whatever it actually reports, same as every phase before it.
2. Phase 5: Rewrite Writer — the first real feature to consume `CloudAIProvider`, and the point where `isAvailable()`/a live `generate()` call actually get driven through a real UI and a real `UITest` for the first time.

**If local Xcode ever exists on this machine**: `xcodegen generate`, open
`VisionIOS.xcodeproj`, and everything here still works locally too — CI
was the necessary path given no Xcode locally, not a permanent substitute
for it.
