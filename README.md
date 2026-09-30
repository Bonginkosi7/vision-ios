# VISION for iOS — Phase 1 (starting the port)

Native Swift/SwiftUI iOS counterpart of the desktop Electron app ("Vision
browser") and the native Android port ("vision-android"). Built the same
way vision-android was: read the real source first, port an honest
equivalent, disclose anything that can't be honestly replicated rather than
fake it. See `/Users/user/.claude/plans/encapsulated-inventing-scone.md`
for the full architecture/roadmap this phase follows.

Repo: https://github.com/Bonginkosi7/vision-ios

## Real, current status

**This machine still doesn't have Xcode installed** — only Command Line
Tools. That blocked all local verification, so instead of leaving `App/`
(SwiftUI + UIKit + WebKit + GRDB) as dead, unverified code, CI does the
verifying: **GitHub Actions** (`.github/workflows/ios.yml`, real Xcode on
GitHub's own macOS runners, triggered on every push to `main`).

### What CI has actually confirmed, as of run [`36685332109`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36685332109)

Both real, both green:

1. **`swift test` passes for real** (not just the local standalone-harness
   run described below) — all cases in `Tests/VisionCoreTests` ran under
   genuine Xcode/XCTest and passed.
2. **The full `App/` target — `xcodebuild build`, real iOS SDK, real iOS
   Simulator destination — compiles successfully.** Every file
   (`MainBrowserView`, `WebViewRepresentable`, `TabManager`, `BrowserTab`,
   `AppDatabase`/`BookmarkStore` via GRDB, `NewTabView`, `DesignSystem`,
   `VisionIOSApp`) type-checks and links against real `SwiftUI`, `UIKit`,
   `WebKit`, and GRDB (resolved as a real remote Swift Package dependency).

**What this does NOT yet mean**: a successful `xcodebuild build` proves the
code is valid and links correctly — it does **not** prove the app behaves
correctly at runtime (does the WKWebView coordinator actually fire, does
the GRDB migration actually run cleanly on first launch, does tapping the
bookmark star actually persist). That needs the app actually launched and
driven in a booted simulator — either locally once Xcode exists, or as a
follow-up CI job that boots a simulator and runs it (not set up yet). Don't
report Phase 1 as "done" — only "compiles clean against a real iOS SDK,"
which is itself a real result, not the finish line.

### Three real bugs this CI loop already caught and fixed

Documented here rather than squashed away, matching this whole project's
convention of keeping a real debugging trail:

1. **XcodeGen generated a project in a newer format than the runner's
   default Xcode could read** (`"future Xcode project file format (77)"`
   against the runner's default Xcode 15.4). Fixed by explicitly selecting
   the newest Xcode installed on the runner rather than trusting the
   default.
2. **A greedy `sed` pattern picked up a simulator's UDID along with its
   name** — a `simctl list` line has two parenthetical groups (UDID, then
   boot state), and `s/^ *(.*) \(.*/\1/`'s greedy capture matched past the
   first one. Fixed by trimming from the first `" ("` onward instead of
   capturing up to it.
3. **`{name:X, OS:latest}` still failed to match** even with the name
   fixed — this runner's "latest" simulator runtime isn't paired with
   every device silhouette (no `OS:latest` entry existed for "iPhone 15
   Pro" specifically). Fixed by targeting one confirmed-available
   simulator directly by UDID instead of a name+OS pairing.

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

## File-by-file (`App/`)

Direct ports of `MainActivity.kt`'s Phase 1 slice, plus `DesignSystem.kt`:

- `VisionIOSApp.swift` — `@main` entry point
- `MainBrowserView.swift` — address bar, back/forward, tab count, bookmark toggle, hosts the active tab
- `WebViewRepresentable.swift` — `UIViewRepresentable` wrapping one `WKWebView` per tab
- `BrowserTab.swift` — mirrors `Tab.kt` (id, title, url, isNewTab)
- `TabManager.swift` — mirrors `MainActivity.kt`'s `tabs`/`activeTabIndex` + create/switch/close/navigate, delegates close-index math to the already-verified `VisionCore.TabIndexing`
- `AppDatabase.swift` / `BookmarkStore.swift` — GRDB port of `BookmarkDbHelper.kt` (one shared `DatabaseQueue`, not 23 separate files — see build plan for why)
- `NewTabView.swift` — real bookmarks row only; no fake shortcuts/widgets yet
- `DesignSystem.swift` — same component list and color tokens as `DesignSystem.kt`, ported to `@ViewBuilder` functions; drawable XML collapses into inline SwiftUI modifiers (disclosed simplification, noted in-file)

`project.yml` (XcodeGen spec) generates the actual `.xcodeproj` in CI —
there's no hand-crafted `.pbxproj` in this repo (too fragile to write
blind without a way to verify it opens), it's regenerated fresh every run.

## Explicitly NOT built yet (disclosed scope trims, not oversights)

History, Downloads, Offline Library, Focus Mode, Private Browsing,
Settings (incl. AI key storage), the Ask VISION chat, every education
screen (Study Materials, Flashcards, Exams, Tutor, Performance, Study
Plan, Paper Review, Rewrite), Rewards/Redeem, Advisor, VISION Ready, Help,
and the overflow menu. Sequencing for all of these is in the build plan's
Phase 2–12 roadmap.

## Next steps

**Once local Xcode exists**: `xcodegen generate`, open `VisionIOS.xcodeproj`,
build and run in the Simulator, live-verify the real behaviors CI can't
check yet (type a URL and confirm navigation, tap the bookmark star,
switch/close tabs, force-quit and relaunch and confirm the bookmark
persisted).

**Without local Xcode (current path)**: extend `.github/workflows/ios.yml`
with a job that boots a simulator, installs the built `.app`, and drives it
— either via `xcodebuild test` against a real `XCUITest` target (not
written yet) or a scripted `simctl launch`/`simctl io screenshot` sequence
— so the *behavioral* gap above gets closed by CI too, not just the build.
