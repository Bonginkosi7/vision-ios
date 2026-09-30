# VISION for iOS — Phase 1 (starting the port)

Native Swift/SwiftUI iOS counterpart of the desktop Electron app ("Vision
browser") and the native Android port ("vision-android"). Built the same
way vision-android was: read the real source first, port an honest
equivalent, disclose anything that can't be honestly replicated rather than
fake it. See `/Users/user/.claude/plans/encapsulated-inventing-scone.md`
for the full architecture/roadmap this phase follows.

## Real, current status — read this before assuming anything below "works"

**This machine does not have Xcode installed** — only Command Line Tools
(`xcode-select -p` → `/Library/Developer/CommandLineTools`). Full Xcode
needs the user's own Apple ID to install, so it hasn't been possible to do
that from here. Two direct consequences:

1. **The `App/` folder (SwiftUI + UIKit + WebKit + GRDB) has never been
   compiled.** It's a faithful, deliberate port of `MainActivity.kt`'s
   Phase 1 slice (see file-by-file notes below) but the iOS SDK these files
   need (SwiftUI's iOS target, `UIViewRepresentable`, `WKWebView`, GRDB via
   SPM) is bundled with full Xcode, not Command Line Tools — there is
   currently no way to build or run it on this machine. Treat every file in
   `App/` as **unverified** until it's actually built and run in Xcode.

2. **`swift build` / `swift test` (Swift Package Manager) don't work here
   either**, even for `Sources/VisionCore` — which has zero platform
   dependencies (no SwiftUI/UIKit/WebKit/GRDB, just `Foundation`). SPM
   internally calls `xcrun --sdk macosx --show-sdk-platform-path`, which
   fails under a Command-Line-Tools-only install in this environment:
   ```
   xcrun: error: unable to lookup item 'PlatformPath' from command line tools installation
   ```

## What's actually real-verified right now, without Xcode

Bare `swiftc` (not SPM) does work here. So rather than leave
`Sources/VisionCore` completely unverified too, its two files —
`AddressResolver.swift` and `TabIndexing.swift`, direct ports of
`AddressResolver.kt` and `TabIndexing.kt` — were:

- **Type-checked** directly: `swiftc -typecheck AddressResolver.swift TabIndexing.swift` → clean, no errors.
- **Actually compiled and run** against all 21 real test cases ported from
  `AddressResolverTest.kt` and `TabIndexingTest.kt` (same inputs, same
  expected outputs), via a standalone `main.swift` harness compiled with
  `swiftc` directly (bypassing the broken SPM toolchain) — **all 21
  passed**. This is genuine behavioral verification of the actual ported
  logic, not a claim — rerun it yourself any time:
  ```bash
  cd /tmp && mkdir -p visioncore_verify && cd visioncore_verify
  # (recreate main.swift from git history / ask Claude to regenerate it)
  swiftc /Users/user/Downloads/vision-ios/Sources/VisionCore/AddressResolver.swift \
         /Users/user/Downloads/vision-ios/Sources/VisionCore/TabIndexing.swift \
         main.swift -o verify_run && ./verify_run
  ```
- The one disclosed real behavioral difference found: `resolveDestination`
  percent-encodes a space as `%20` (Swift's `addingPercentEncoding`) where
  the Kotlin/Java port uses `+` (`URLEncoder`) — different literal bytes,
  identical resolved destination for every real search engine. Noted in
  `AddressResolver.swift`'s doc comment, not silently assumed identical.

`Tests/VisionCoreTests/*.swift` hold the same 21 cases as real `XCTest`
cases (mirroring `AddressResolverTest.kt`/`TabIndexingTest.kt` exactly) —
they're written and ready, but **have not themselves been run**, since
`swift test` is what's broken here. Once Xcode exists, run them for real
(`swift test` or Xcode's Test navigator) as the first verification step —
don't assume the standalone-harness pass above stands in for it forever.

## What's written but NOT verified (`App/`)

Direct ports of `MainActivity.kt`'s Phase 1 slice, plus `DesignSystem.kt`:

- `VisionIOSApp.swift` — `@main` entry point
- `MainBrowserView.swift` — address bar, back/forward, tab count, bookmark toggle, hosts the active tab
- `WebViewRepresentable.swift` — `UIViewRepresentable` wrapping one `WKWebView` per tab
- `BrowserTab.swift` — mirrors `Tab.kt` (id, title, url, isNewTab)
- `TabManager.swift` — mirrors `MainActivity.kt`'s `tabs`/`activeTabIndex` + create/switch/close/navigate, delegates close-index math to the already-verified `VisionCore.TabIndexing`
- `AppDatabase.swift` / `BookmarkStore.swift` — GRDB port of `BookmarkDbHelper.kt` (one shared `DatabaseQueue`, not 23 separate files — see build plan for why)
- `NewTabView.swift` — real bookmarks row only; no fake shortcuts/widgets yet
- `DesignSystem.swift` — same component list and color tokens as `DesignSystem.kt`, ported to `@ViewBuilder` functions; drawable XML collapses into inline SwiftUI modifiers (disclosed simplification, noted in-file)

None of this has run in a simulator. Do not report any of it as "working"
until it has.

## Explicitly NOT built yet (disclosed scope trims, not oversights)

History, Downloads, Offline Library, Focus Mode, Private Browsing,
Settings (incl. AI key storage), the Ask VISION chat, every education
screen (Study Materials, Flashcards, Exams, Tutor, Performance, Study
Plan, Paper Review, Rewrite), Rewards/Redeem, Advisor, VISION Ready, Help,
and the overflow menu. Sequencing for all of these is in the build plan's
Phase 2–12 roadmap.

## Next steps once Xcode is actually installed and working

1. Confirm with `xcodebuild -version` — should print a real version, not the Command Line Tools error.
2. Create a new Xcode iOS App project named `VisionIOS`, bundle ID `com.vision.browser`, SwiftUI lifecycle, iOS 16.0 deployment target.
3. Add this repo's `Package.swift` as a local Swift package dependency (for `VisionCore`), and add GRDB.swift via File → Add Package Dependencies → `https://github.com/groue/GRDB.swift`.
4. Add every file under `App/` to the new app target.
5. Run `swift test` for real for the first time — confirm the 21 cases still pass under the real toolchain, not just the standalone harness above.
6. Build and run in the iOS Simulator (`mcp__Claude_Code_iOS_Simulator__*` tools) — live-verify: type a URL and confirm navigation, tap the bookmark star, switch/close tabs, force-quit and relaunch and confirm the bookmark persisted. Only after this passes does Phase 1 actually count as done.
