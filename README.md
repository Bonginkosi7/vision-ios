# VISION for iOS — Phase 1 (starting the port)

Native Swift/SwiftUI iOS counterpart of the desktop Electron app ("Vision
browser") and the native Android port ("vision-android"). Built the same
way vision-android was: read the real source first, port an honest
equivalent, disclose anything that can't be honestly replicated rather than
fake it. See `/Users/user/.claude/plans/encapsulated-inventing-scone.md`
for the full architecture/roadmap this phase follows.

Repo: https://github.com/Bonginkosi7/vision-ios

## Real, current status: Phase 1 is behaviorally verified, for real

**This machine still doesn't have Xcode installed** — only Command Line
Tools. That blocked all local verification, so **GitHub Actions** does the
verifying instead (`.github/workflows/ios.yml`, real Xcode on GitHub's own
macOS runners, triggered on every push to `main`).

As of run [`36691346964`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36691346964), **both CI jobs are green**, and this time that means more than "it compiles":

1. **`swift test`** — all of `Tests/VisionCoreTests` pass under real Xcode/XCTest.
2. **`xcodebuild test`, a real booted iOS Simulator** — the actual built `.app`
   is installed, launched, and driven by `UITests/VisionIOSUITests.swift`:
   - the address bar and New Tab page render on a fresh launch
   - typing a real address and submitting it navigates the real WKWebView
     and the address bar reflects the real, resolved, loaded URL
   - tapping the bookmark star saves it, and — the actual bar this phase's
     verification plan set — **force-terminating the process and relaunching
     the app shows the bookmark was genuinely read back from a real,
     persisted GRDB/SQLite database**, not an in-memory flag

That's the real acceptance bar for "Phase 1 done": not just "it compiles,"
but launched, driven, and behaviorally confirmed.

## Seven real bugs this CI loop found and fixed

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
`app.debugDescription` accessibility tree (plain text) on failure — worth
keeping for any future failures here too.

## What was verified locally, without Xcode, before CI existed

Bare `swiftc` works here even though Xcode itself doesn't. Before GitHub
Actions was set up, `Sources/VisionCore`'s two files —
`AddressResolver.swift` and `TabIndexing.swift`, direct ports of
`AddressResolver.kt`/`TabIndexing.kt` — were type-checked directly and
actually compiled and run against all 21 real test cases ported from
`AddressResolverTest.kt`/`TabIndexingTest.kt`, via a standalone `main.swift`
harness (bypassing SPM's own broken toolchain on this machine — `swift
build`/`swift test` fail here with `xcrun: error: unable to lookup item
'PlatformPath'`). All 21 passed. Superseded now by the real `swift test`
CI run above, but kept as a record that even the "no Xcode at all" state
had a genuine verification path, not a guess.

The one disclosed real behavioral difference found along the way:
`resolveDestination` percent-encodes a space as `%20` (Swift's
`addingPercentEncoding`) where the Kotlin/Java port uses `+`
(`URLEncoder`) — different literal bytes, identical resolved destination
for every real search engine. Noted in `AddressResolver.swift`'s doc
comment.

## File-by-file

Direct ports of `MainActivity.kt`'s Phase 1 slice, plus `DesignSystem.kt`:

**`App/`** (SwiftUI + UIKit + WebKit + GRDB, real iOS target):
- `VisionIOSApp.swift` — `@main` entry point
- `MainBrowserView.swift` — address bar, back/forward, tab count, bookmark toggle, hosts the active tab via `ActiveTabContent`
- `WebViewRepresentable.swift` — `UIViewRepresentable` wrapping one `WKWebView` per tab
- `BrowserTab.swift` — mirrors `Tab.kt` (id, title, url, isNewTab)
- `TabManager.swift` — mirrors `MainActivity.kt`'s `tabs`/`activeTabIndex` + create/switch/close/navigate, delegates close-index math to `VisionCore.TabIndexing`
- `AppDatabase.swift` / `BookmarkStore.swift` — GRDB port of `BookmarkDbHelper.kt` (one shared `DatabaseQueue`, not 23 separate files — see build plan for why)
- `NewTabView.swift` — real bookmarks row only; no fake shortcuts/widgets yet
- `DesignSystem.swift` — same component list and color tokens as `DesignSystem.kt`, ported to `@ViewBuilder` functions; drawable XML collapses into inline SwiftUI modifiers (disclosed simplification, noted in-file)

**`UITests/`** — `VisionIOSUITests.swift`, the real behavioral verification described above.

`project.yml` (XcodeGen spec) generates the actual `.xcodeproj` (app target
+ `VisionIOSUITests` target + a `VisionIOS` scheme wiring both) in CI —
there's no hand-crafted `.pbxproj` in this repo, it's regenerated fresh
every run.

## Explicitly NOT built yet (disclosed scope trims, not oversights)

History, Downloads, Offline Library, Focus Mode, Private Browsing,
Settings (incl. AI key storage), the Ask VISION chat, every education
screen (Study Materials, Flashcards, Exams, Tutor, Performance, Study
Plan, Paper Review, Rewrite), Rewards/Redeem, Advisor, VISION Ready, Help,
and the overflow menu. Sequencing for all of these is in the build plan's
Phase 2–12 roadmap.

## Next steps

Phase 1 is done and behaviorally verified. Next: Phase 2 (History,
Downloads, Offline Library, Private Browsing) per the build plan's
roadmap, extending both `App/` and `UITests/` the same way — real port
first, then a real UI test that launches and drives it, iterating on
whatever CI actually reports rather than assuming it works.

**If local Xcode ever exists on this machine**: `xcodegen generate`, open
`VisionIOS.xcodeproj`, and everything here still works locally too — CI
was the necessary path given no Xcode locally, not a permanent substitute
for it.
