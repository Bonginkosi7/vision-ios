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

**A real cross-source sweep** (comparing the overflow menu's real entry
list against `MainActivity.kt`'s own `showOverflowMenu()`, item by
item, rather than assuming everything already landed) found two real,
previously-undisclosed gaps — and a stale code comment that had
actually already flagged them months ago and was never revisited:
`Autofill` (stays deferred — it depends on real credential storage this
app doesn't have, a bigger, security-sensitive undertaking, not a quick
fix) and a dedicated **Bookmarks screen** (`BookmarksActivity.kt`) —
New Tab's own bookmarks row was never a substitute for Android's real
standalone manage screen. Closed the second one: `BookmarksView.swift`
mirrors `HistoryView.swift`'s established list/open/delete pattern
exactly, since `BookmarkStore.swift` already had every real method this
screen needed since Phase 1 — no new data-layer work required. Run
[`37080415562`](https://github.com/Bonginkosi7/vision-ios/actions/runs/37080415562)
passed fully green on the first attempt: all 28 UI tests, all 154
VisionCore unit tests.

**Phase 18** (Study Material hub) is done — the biggest single phase
this project has shipped, and its own real bug hunt spanned five
pushes across several genuinely different kinds of failure. Run
[`37014842971`](https://github.com/Bonginkosi7/vision-ios/actions/runs/37014842971)
failed on the exact container-identifier-clobbers-a-child-Button quirk
this README already documented from Phase 8 and Phase 17 — a THIRD
real hit of the same class, this time `.accessibilityIdentifier("studyUntaggedBanner")`
on a `DesignSystem.card` overwriting its own "Review" `Button`'s
identifier. Fixed by moving it to the one `Text` actually asserted on,
and auditing (and proactively fixing a second, not-yet-triggered
instance in the Untagged row) every other identifier in the new file.
The next run,
[`37035641052`](https://github.com/Bonginkosi7/vision-ios/actions/runs/37035641052),
failed identically on two separate real attempts — not a flake, since
the exact same assertion ("expected the real Education submenu to
exist") kept failing right after the new Review-tab test's
`app.swipeDown()` — plus one pure GitHub Actions infrastructure failure
("runner lost communication with the server") in between, unrelated to
the code. The real root cause: `OfflineLibraryView` had no "Done"
button at all, unlike every other sheet in this app — `swipeDown()`
was never a proven dismissal technique in this suite, and the real fix
was adding the same real `Done` button every sibling screen already
has, then using it instead of a gesture. Run
[`37055528045`](https://github.com/Bonginkosi7/vision-ios/actions/runs/37055528045)
then passed fully green: all 27 UI tests, all 154 VisionCore unit
tests.

**Phase 17** (VISION Ready) is done — a genuinely multi-push real bug
hunt, every failure a different kind. Run
[`36994419107`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36994419107)
failed on the exact same accessibility-identifier merging quirk Phase 6
found by its own mirror path: `.accessibilityIdentifier("visionReadyPercent")`
applied to an `HStack` wrapping two `Text` views made SwiftUI propagate
that one identifier onto *both* child `StaticText`s, so reading `.label`
on it threw a real "multiple matching elements" error — confirmed via
the actual captured accessibility-tree dump in the failure, not a guess.
Fixed by moving the identifier onto the one `Text` actually asserted on.
The next run,
[`36998118327`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36998118327),
failed on the new UI test's own first assertion — "a fresh install has
no bookmarks yet" was false, because this whole UI test suite shares one
real app install/database for the entire run, and
`test_bookmarkingAPage_survivesAppTermination` (alphabetically first)
had already bookmarked `example.com` and left it bookmarked permanently
by the time this test ran alphabetically late — a real, previously-
undocumented fact about how this suite's state actually works. Rewritten
to use `example.org` (untouched by any other test) and assert only
order-independent real facts. The next run,
[`37001961452`](https://github.com/Bonginkosi7/vision-ios/actions/runs/37001961452),
failed because `OfflineLibraryView` has no "Done" toolbar button of its
own — it only ever dismisses by tapping a row — so the test's "Done" tap
actually targeted VisionReadyView's own button, still covered by the
presented sheet, and the real AX layer refused to scroll to it. Fixed by
tapping the saved row to dismiss, the view's own real behavior. Run
[`37006001658`](https://github.com/Bonginkosi7/vision-ios/actions/runs/37006001658)
then passed fully green: all 25 UI tests, all 133 VisionCore unit tests.

**Phase 16** (Ask VISION chat) is done — run
[`36985916405`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36985916405)
passed fully green on the first attempt after a genuinely hard real bug
hunt spanning five pushes. The symptom first showed up as the AI Tutor
UI test failing, looking like one isolated flake — but fixing that (and
reverting a wrong first diagnosis along the way) didn't fix the next
run, which failed six *different*, previously rock-solid tests at their
first `openMenu` call. Three more attempts to make `openMenu` itself
smarter (`isHittable` + swipe-up; retry-if-tapped-item-still-exists;
retry-if-moreMenuButton-still-exists) each got disproven by the very
next real CI run — one introduced a new error class, one left a real
failure uncaught, one failed almost the entire suite outright. Reverting
`openMenu` to the exact version that had been reliable across Phases
1–10 *still* showed the same failures on this same build, which was the
real turning point: it proved the test helper was never the bug.

The actual cause was architectural, not a test problem at all: the
overflow menu had grown to 21 flat items, and Android's own
`MainActivity.kt` — read for the first time specifically to check this
— has a doc comment on its own `showOverflowMenu()` confirming Android
hit this *exact* wall already: a single flat popup became genuinely
unmanageable, and Android restructured into a real accordion with
"Education"/"Settings" sub-groups (PopupMenu silently drops nested
submenus, so Android built a custom `PopupWindow` to get real nesting).
Matching that real architecture — an actual nested SwiftUI `Menu` for
the 8 education screens, dropping the top level from 21 items to 14 —
is what actually fixed it; no test-side change was needed once the real
over-sized menu was gone. Final counts: 24 UI tests, 127 VisionCore unit
tests.

**Phase 15** (Help) is done — run
[`36942376967`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36942376967)
passed fully green after four re-runs: three different, completely
unrelated tests (`test_offlineSaveAndReopen`,
`test_focusModeBlocksConfiguredDomainAndEndsViaTheRealBridge`,
`test_changingSearchEngineAffectsRealNavigation` twice) each hit the
same real CI-runner-slowness signature confirmed repeatedly before in
this project — isolated timeouts on previously-stable tests, never the
same test twice in a row, no code change needed. The real bugs this
push's first two attempts did catch (both fixed, both confirmed by
these same green re-runs): the AI Tutor UI test's suggestion-chip tap
could be silently swallowed by the surrounding horizontal `ScrollView`'s
own gesture recognizer (reports success at the OS level, but `ask()`
never runs) — rewritten to use only the manual text-input path, which
has no such container; and Study Plan's exam-date picker only committed
a real date on an actual calendar interaction, so opening the sheet and
tapping "Set Date" without touching the grid left `examDate` nil — fixed
to commit today's date the moment the sheet appears, matching Android's
own `DatePickerDialog`. Final counts: 23 UI tests, 118 VisionCore unit
tests.

**Phase 14** (Paper Review) is done, part of the same run above — real
AI-backed spelling/grammar/writing feedback that hands off to Rewrite
Writer. Its own push separately caught and fixed a real compile error:
`try?` on an Optional-returning throwing function flattens to a single
Optional in this toolchain (confirmed by the actual compiler error, not
assumed), so `PerformanceCalculator.masteryForTopic`'s defensive
two-step `guard let x = try? ..., let y = x` was invalid.

**Phase 13** (Study Plan) is done, part of the same run above — a
deterministic weekly plan with real "Start session" tracking straight
into Flashcards or a generated mock test.

**Phase 12** (Performance) is done, part of the same run above — a
real per-topic mastery dashboard, closing the `reviewEventsForTopic`/
`markedAnswersForTopic` trims Phase 9/10 had disclosed.

**Phase 11** (AI Tutor) is done, part of the same run above —
document-grounded or general AI Q&A chat, reusing the same
`CloudAIProvider`/`StructuredAI` plumbing every other AI feature here
already proved reaches the real APIs.

**Phase 10** (Exams) is done — run
[`36926053584`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36926053584)
passed fully green on the first attempt: all 18 UI tests, all 88
VisionCore unit tests. No real bug this time — the new combined test
(hand-authored exam created, taken, and marked 100% correct with zero
AI involved, plus the AI-generation honest-error path) passed first try.

**Phase 9** (Flashcards) is done — run
[`36911066302`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36911066302)
passed fully green on the second attempt: the first attempt failed on
`test_changingSearchEngineAffectsRealNavigation` (a test completely
unrelated to this phase) with the address bar showing the *correct*
value just after a 104-second timeout — the same real CI-runner-
slowness signature confirmed twice before in this project — and both
of this phase's own new tests already passed in that same run.
Re-running just the failed job (no code change) confirmed it: all 17
UI tests, all 74 VisionCore unit tests.

**Phase 8** (My Materials: document import, extraction, AI topic
extraction) is done — the longest real CI loop of any phase so far,
six iterations deep before genuinely green. The first few failures
were real: a tap-before-wait race in the new UI test, then a genuine
SwiftUI accessibility-identifier overwrite (the same class of bug
Phase 7 found, but worse — it clobbered a child *Button's* own
identifier, not just a StaticText's). After those, one test kept
failing on the exact same symptom (the seeded document mysteriously
vanishing mid-test) across three further attempts, including two
fixes that turned out to target the wrong mechanism — the eventual
real cause, found only by downloading the `.xcresult` and reading the
app's own real console output twice, was that tapping "Process"
could shift the row's Delete button into the just-removed Process
button's screen position in time to catch a stray touch, genuinely
deleting the seeded fixture's real row and real file. Fixed for good
by moving Delete to a real swipe action instead of chasing the exact
timing. Run
[`36907386138`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36907386138)
passed fully green — all 16 UI tests, all 58 VisionCore unit tests.
Full story below.

**Phase 7** (Rewards) is done — a longer real CI loop than any phase
before it: the first push's run
[`36864175163`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36864175163)
failed on a genuine toolbar-overflow bug (`historyButton` pushed off
the real screen edge once an 8th always-visible icon was added), and
fixing that *properly* — matching Android's real single-overflow-menu
architecture instead of patching the symptom — took two more real
iterations (a SwiftUI `Menu` tap quirk, then a leaked `Timer` in
`FocusView`) before run
[`36872065033`](https://github.com/Bonginkosi7/vision-ios/actions/runs/36872065033)
passed fully green: all 15 UI tests, all 50 VisionCore unit tests. See
below for the full story — it's a real one, kept rather than squashed,
same as Phase 1's own bug log.

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

## Phase 18: Study Material hub

A port of `StudyMaterialActivity.kt`/`StudyTaxonomy.kt`/
`StudyReviewDbHelper.kt` — a real taxonomy browser (Home → Grades/
Categories → Subjects/Resources, with breadcrumb back-navigation,
search, and a filter panel), tagging for the user's own uploaded
documents, and a folded-in spaced-repetition Review tab over offline-
saved "education"-category pages.

- **`Sources/VisionCore/StudyTaxonomy.swift`** (pure): the real level/
  grade/subject/resource-type/language option lists — direct port of
  the CAPS-curriculum data in `StudyTaxonomy.kt`, never fabricated
  textbook content, just real public category *names* the user assigns
  to their own files.
- **`Sources/VisionCore/StudyDocumentMatching.swift`** (pure): unifies
  Android's two real filter call sites — `docsFor`'s in-memory browse
  filtering and `search`'s SQL `WHERE` clause — into one matcher, since
  iOS loads every document into memory either way.
- **`Sources/VisionCore/StudyReviewLogic.swift`** (pure): the real
  Leitner-tier due/not-due/streak math, `now`/`calendar` injectable for
  testability, same pattern `MasteryEngine` established. 44 standalone-
  harness checks during development + 23 real `XCTest` cases across
  `StudyTaxonomyTests`/`StudyDocumentMatchingTests`/`StudyReviewLogicTests`.
- **`App/AppDatabase.swift`**: `v11_phase18` adds the real taxonomy/
  `offlineReadyAt` columns to `studyDocument` — closing the exact gap
  the Phase 5 migration's own comment named as deferred — plus the two
  `studyReview` tables.
- **`App/StudyReviewStore.swift`** (new): GRDB I/O wrapping the pure
  `StudyReviewLogic`.
- **`App/StudyMaterialView.swift`** (new): the real screen — Browse and
  Review tabs, a real tag-assignment sheet (level drives grade+subject
  or category), and `ShareLink` for "Open" (see below).

**Disclosed, deliberate difference from Android.** Android folds "View"
and "Download" into one `FileProvider` + `ACTION_VIEW` intent. iOS's
real equivalent of "hand this file to another app" is a share sheet —
"Open" here presents a `ShareLink` instead, same real app-interop
philosophy, different OS-native mechanism.

**Also closes a real, pre-existing gap versus Android**, found while
scoping the Review tab: `OfflineLibraryView` had no way to ever set a
non-"general" category, so Review could never have had anything real
to show. Added the real per-item category reassignment menu Android's
own `OfflineAdapter.kt` already has, plus (found during this phase's
own bug hunt, see "Real, current status") the `Done` button
`OfflineLibraryView` had been missing entirely.

### Phase 18 UI tests

`test_studyMaterialTagsAUntaggedDocumentAndTheRealTaxonomyRoundTrips` —
uses My Materials' own `-UITestSeedMaterial` fixture (it starts
genuinely untagged), tags it with a real level/grade/subject/year/
language, and confirms the exact same real taxonomy routes back through
Home → Basic Education → Grade 7–9 → Physical Sciences, then confirms
"Mark offline" flips to "Offline ready".

`test_studyMaterialReviewTabTracksARealOfflineSavedEducationPage` —
saves a real page (`example.net`, untouched by any other test in this
suite), reassigns its category to "Education" from the Offline
Library, confirms a real due entry appears in Review, and that "Got it"
advances the real schedule into a genuine caught-up state with a real
1-day streak — straight from `StudyReviewLogic`'s tier math, never a
fabricated schedule.

## Phase 17: VISION Ready

A port of `VisionReadyActivity.kt`/`ReadinessLogic.kt`, itself the
Android counterpart of desktop's vision-ready page
(`src/renderer/vision-ready/vision-ready.ts`): a real "is my offline
setup actually ready" screen.

- **`Sources/VisionCore/ReadinessLogic.swift`** (pure): `compute(bookmarkUrls:offlineUrls:offlineCategories:) -> ReadinessResult`
  — percent of bookmarks also saved offline, `nil` (not `0`) when there
  are no bookmarks yet, plus a per-category breakdown. Direct port of
  Android's own `ReadinessLogic.kt`, reshaped to take plain `[String]`s
  instead of `Bookmark`/`OfflineItem` so this file stays free of any
  App-layer/GRDB dependency. 23 real test cases (17 from a standalone
  `swiftc` harness during development, 6 real `XCTest` cases in
  `Tests/VisionCoreTests/ReadinessLogicTests.swift`, all passing in CI).
- **`App/ConnectivityMonitor.swift`** (new): real, current network
  reachability via `NWPathMonitor` — the iOS counterpart of Android's
  `ConnectivityUtil.kt`. Published/observed rather than a one-shot call,
  since iOS has no synchronous "is online right now" API the way
  Android's `ConnectivityManager.getNetworkCapabilities` does.
- **`App/AppSettings.swift`**: a real, adjustable offline storage limit
  (200/500/1000/2000/5000 MB, default 500 — the exact same options as
  Android's own spinner), backing the "used of N MB" stat on this
  screen. Exposed as a real picker in `App/SettingsView.swift`.
- **`App/VisionReadyView.swift`** (new): connectivity row, the real
  Offline Readiness card (percent/progress bar, saved-vs-bookmarked and
  storage-used-vs-limit stats, category breakdown, tapping either the
  card or "Manage offline content" opens the real Offline Library), and
  three honest cards below it.

**Disclosed, deliberate difference from Android, not a missed port.**
Android's own "Keeping Pages Up to Date" card has a real `Switch`
because Android ships a real Smart Cache background-refresh worker
(`BackgroundRefreshScheduler`) for it to control. iOS has never had that
worker — disclosed as far back as the Phase 2 migration comment in
`AppDatabase.swift` — so a switch here would control nothing real. This
card instead states that honestly in its own words, the same way Sports
(no live data provider configured, true on any platform) and Maps (not
built on iOS yet) are already honestly disabled below it.

New `menu_visionReady` entry in the overflow menu, same flat placement
Android's own `MainActivity.kt` uses (right after Rewards, before
Offline Library).

### Phase 17 UI test

`test_visionReadyShowsRealNumbersAfterBookmarkingAndSavingOffline` —
bookmarks a real page (`example.org`, specifically chosen because no
other test in this suite ever touches its bookmark/offline state),
saves it offline, and confirms a real percent, real stats, and a real
"general" category entry appear — never a fabricated number — then
opens Offline Library from this screen and confirms the same real saved
page is there. Doesn't assert an exact percent or a pristine starting
state: see the real bug hunt in "Real, current status" above for why
that's genuinely unsafe in this suite, not just over-caution.

## Phase 16: Ask VISION chat

A scoped-down port of `ChatActivity.kt`/`ChatAiLogic.kt`/
`ChatCategoryLogic.kt`/`ChatSessionDbHelper.kt`.

- **`Sources/VisionCore/ChatCategoryLogic.swift`** (pure): classifies
  each message locally into one of six real categories (Learn/
  Research/Create/Plan/Work/General) via plain keyword/pattern
  matching — deliberately not a second LLM call pretending to be deep
  understanding — and builds a category-specific system instruction.
  `ChatSessionTitle.derive` titles a session from its own real first
  message, same "no AI call pretending to summarize" discipline.
- **`App/ChatAI.swift`**: tries each configured provider in order and
  returns the first real free-text reply, same shape as `TutorAI`.
- **`App/ChatSessionStore.swift`** (GRDB): real, persisted multi-session
  conversations.
- **`App/AskVisionView.swift`**: a flat real session list (newest
  first) plus a plain conversation view.

**Disclosed scope trim.** Android's voice input, chat export, date-
grouped/searchable session history, and per-message "Remember this"/
"Save for offline" quick actions aren't ported — each is tied to a
real capability this app doesn't have yet: a Memory feature, or a
hidden-`WKWebView` live-page-fetch (`FetchLivePage.kt` — loads an
arbitrary URL in an off-screen `WKWebView` and reads
`document.body.innerText`, a genuinely trickier, higher-risk capability
than anything built so far, deliberately left for its own phase rather
than rushed in alongside everything else here).

### Phase 16 UI test

`test_askingVisionWithNoCloudKeyConfigured` — the same honest "not
configured" path as every other AI feature, through a real session's
full round-trip: a fresh empty session list, starting a new chat,
sending a message and getting the real reply with the real "Learn"
category label, then confirming that same real session reappears in
the list titled from its own first message, and can be deleted.

### The real menu restructuring (also this push)

Explained in full in "Real, current status" above — the overflow menu's
8 education screens now live under a real nested "Education" submenu,
matching a real, documented decision in Android's own `MainActivity.kt`
rather than a test-side workaround. `UITests/VisionIOSUITests.swift`
gained `openEducationMenu`, mirroring `openMenu` but drilling into the
submenu first.

## Phase 15: Help

A genuine rewrite of `HelpContent.kt`/`HelpActivity.kt` for iOS's own
actual feature set as of Phase 14 — not a translation of either
Android's or desktop's copy, both of which describe things this app
doesn't have (Redeem, Ask VISION chat, an on-device model, Android's
separate Study Material hub). Describing those would be exactly the
kind of fabricated-capability claim this app avoids everywhere else.

- **`App/HelpContent.swift`**: five real sections (Downloads & Offline,
  Focus Mode, VISION Education, Wellbeing & Rewards, Privacy) covering
  only what's actually built — including Performance and My Week, added
  this same push.
- **`App/HelpView.swift`**: a static, real display of those sections.

### Phase 15 UI test

`test_helpShowsRealDocumentationSections` confirms the real first and
last Help cards render by their own accessibility identifiers (not a
container-level one — see MaterialsView's own doc comment on why).

## Phase 14: Paper Review

Direct port of `PaperReviewLogic.kt`/`PaperReviewActivity.kt`, same
real/pure split as every other AI feature here: a real spelling/grammar
check, general improvement suggestions, and one honest, clearly-labeled
writing-quality opinion that explicitly never claims to have checked
the text against any plagiarism database — this app has no corpus or
web access to check against, and the system instruction says so.

- **`Sources/VisionCore/PaperReviewLogic.swift`** (pure): the system
  instruction, 12,000-char bounding, and permissive JSON parsing.
- **`App/PaperReviewer.swift`**: the real AI call orchestration, reusing
  the same `StructuredAI`/`CloudAIProvider` plumbing every other AI
  feature already proved reaches the real Anthropic/OpenAI APIs.
- **`App/PaperReviewView.swift`**: pick a real processed document,
  review it, and "Rewrite this document →" hands the same real reviewed
  text straight to `RewriteView`'s existing `initialText` parameter.

### Phase 14 UI test

`test_paperReviewWithNoCloudKeyConfigured` — the same honest "Cloud AI
isn't configured" path already established for Rewrite Writer/Topics/
Flashcards/Exams, against the same real seeded-and-processed fixture.

## Phase 13: Study Plan

Direct port of `StudyPlanGenerator.kt`/`StudyPlanDbHelper.kt`/
`StudySessionLogic.kt`/`StudyPlanActivity.kt` — "My Week": a
deterministic, rules-based weekly plan (no AI call, per desktop's own
confirmed V1 scope) built from a student's real topic mastery, with
real "Start session" tracking straight into Flashcards or a generated
mock test.

- **`Sources/VisionCore/StudyPlanGenerator.swift`** (pure): 5 weekday
  sessions allocated across real level-1 topics proportional to a
  mastery/exam-phase-derived weight, via the largest-remainder method
  so integer slot counts sum exactly, plus one always-appended mock-test
  session once real topics exist to build a plan around. A final-review
  phase (exam within 7 days) gives strong topics zero weight — and if
  *only* strong topics exist, the real result is zero items, not a
  padded mock test either.
- **`App/StudyPlanStore.swift`** (GRDB): real plans/items/sessions.
  Android's own `currentPlan` isn't ported — genuinely unused even in
  Android's own codebase.
- **`App/StudySessionManager.swift`**: the real session lifecycle —
  recomputes the same topic's mastery after studying, awards
  `studyPlanTaskCompleted`/`studySessionCompleted` on completion, plus
  a one-time `eduMasteryMilestone` bonus the first time a topic flips to
  "strong" (`RewardRules.swift` now lists every real event type
  Android's own `RewardRules.kt` defines). Android's own
  `masteryForTopic` (used only here) closes the trim Phase 12's own
  `PerformanceCalculator` had disclosed.
- **`App/StudyPlanView.swift`**: an exam-date picker (commits "today"
  the moment it opens, matching Android's own `DatePickerDialog`), a
  7-day plan grid, and "Start session" launching directly into
  `FlashcardsView` or `GenerateExamView`→`TakeExamView` with the real
  session carried through — closing the `sessionId`-related trims
  those three views had disclosed since Phase 9/10. A shared
  `SessionConfidencePrompt.swift` is reused by both.

### Phase 13 UI test

`test_studyPlanShowsHonestEmptyPlanAndExamDateRoundTrips` — with no
real AI-identified topic ever existing in this CI environment (same
honest boundary Phase 12's own test hits), a generated plan is
genuinely empty; also exercises the real exam-date picker round-trip
(pick, see the real countdown, clear it back to unset).

## Phase 12: Performance

Direct port of `MasteryEngine.kt`/`PerformanceLogic.kt`/
`PerformanceActivity.kt` — a real per-topic mastery dashboard.

- **`Sources/VisionCore/MasteryEngine.swift`** (pure): recency-weighted
  correct/total ratio across both flashcard reviews and marked exam
  answers together, the same honest "notAssessed" floor below 3 real
  data points, and rolling subtopics up into their parent topic
  weighted by each subtopic's own sample count.
- **`App/PerformanceCalculator.swift`**: closes two trims Phase 9/10 had
  disclosed by adding real `FlashcardStore.reviewEventsForTopic` and
  `ExamStore.markedAnswersForTopic`. Android's own `getWeakTopics`/
  `getStrongTopics` aren't ported — genuinely unused even in Android's
  own `PerformanceLogic.kt`.
- **`App/PerformanceView.swift`**: All Topics / Top Strengths / Needs
  Attention, same structure and copy as Android's own screen.

### Phase 12 UI test

`test_performanceShowsHonestEmptyStatesWithNoRealTopicData` — same
honest boundary as above: no real topic can exist without a configured
AI key, so the real, correct result for both "All materials" and one
specific document is Performance's own empty states, never fabricated
mastery data.

## Phase 11: AI Tutor

Direct port of `TutorLogic.kt`/`TutorDbHelper.kt`/`TutorActivity.kt` —
document-grounded or general AI Q&A chat.

- **`Sources/VisionCore/TutorLogic.swift`** (pure): the grounded-or-
  general system instruction (honest about *how* it's grounded — the
  whole bounded document text, not desktop's real keyword-scored chunk
  retrieval, which this app has no chunking layer to support), and
  conversation-history trimming.
- **`App/TutorAI.swift`**: tries each configured provider in order and
  returns the first real free-text reply — simpler than `StructuredAI`
  since there's no JSON to parse or retry.
- **`App/TutorStore.swift`** (GRDB): real sessions/messages. No separate
  past-sessions list — Android's own `TutorActivity` doesn't have one
  either; one real session persists for the life of the screen.
- **`App/TutorView.swift`**: "General tutoring" or a real processed
  document, suggestion chips or typed questions, honestly labeled by
  real source (grounded / general AI / not configured).

### Phase 11 UI test

`test_askingTheAITutorWithNoCloudKeyConfigured` uses only the manual
text-input path (see above for why), asking twice to prove `TutorStore`
persisted and reloaded the first real session's messages rather than
losing them between turns, and confirms the real "No cloud AI
configured" source label.

## Phase 10: Exams

Direct port of the scoped-down slice of `ExamDbHelper.kt`/
`ExamGenerationLogic.kt`/`ExamMarking.kt`/`ShortAnswerMarkingLogic.kt`/
`CreateExamActivity.kt`/`GenerateExamActivity.kt`/`TakeExamActivity.kt`/
`ExamsActivity.kt`/`ExamsAdapter.kt`. Reached via a new "Exams" entry in
the overflow menu.

- **`Sources/VisionCore/ExamMarking.swift`** (pure): real local
  MCQ/true-false comparison and score-percent math — no AI involved,
  works fully offline, direct port of `ExamMarking.kt`.
- **`Sources/VisionCore/ExamGenerationLogic.swift`** (pure): the real
  system instruction (reusing `TopicTagging` exactly as Flashcards
  does), 12,000-char bounding, and permissive JSON parsing across all
  three question types (`RawExamQuestion`), direct port of
  `ExamGenerationLogic.kt`.
- **`Sources/VisionCore/ShortAnswerMarkingLogic.swift`** (pure): the
  real batched-marking prompt and response parsing for short-answer
  questions — one call covers every still-unmarked short-answer
  question in an attempt together, same real/pure split established
  for `TopicExtractionLogic`/`TopicExtractor` and
  `FlashcardGenerationLogic`/`FlashcardGenerator`. The real network
  call lives in `App/ShortAnswerMarker.swift`.
- **`App/ExamStore.swift`** (GRDB) + **`App/ExamGenerator.swift`**:
  real test/question/attempt/answer storage, instant local MCQ/
  true-false marking via `ExamMarking`, and the real AI call
  orchestration for AI-generated tests, reusing the exact
  `StructuredAI`/`CloudAIProvider` plumbing already proven by Topics
  and Flashcards.
- **`App/CreateExamView.swift`**: hand-author an MCQ/true-false exam
  entirely offline — no AI involved at all, since a hand-authored
  short-answer "model answer" would have no AI grading behind it to
  genuinely compare against (same reasoning Android applies).
- **`App/GenerateExamView.swift`**: pick a real processed document,
  choose how many of each question type, generate a real test grounded
  in its real extracted text (optionally topic-tagged).
- **`App/TakeExamView.swift`**: take any real saved test — real local
  instant marking for MCQ/true-false, one real batched AI call for any
  short-answer questions, a real countdown timer that auto-submits at
  zero for timed tests, and a real `eduTestCompleted` reward once the
  whole attempt is genuinely, fully marked (closes a Phase 7 trim —
  `RewardRules.swift` had deferred this event type specifically until a
  real trigger existed; Advisor's weekly stats also gained the matching
  real "Learning" row).

**Disclosed scope trim: Tutor, Performance, and Study Plan are not
ported.** The build plan's original "Phase 9" bundle is now fully
split: Flashcards (Phase 9) and Exams (Phase 10) are done, but
Android's own dependency order still gates the rest — Performance's
mastery calculation needs real Flashcards/Exams data (both now exist)
before it can honestly run, and Study Plan needs Performance. Tutor has
no such dependency but is its own real scope. Each gets its own later
phase.

Within what *is* built: Android's `markedAnswersForTopic` (feeding
`MasteryEngine` with per-topic `MasteryEvent` rows) isn't ported — its
whole purpose is Performance's mastery calculation, which doesn't exist
on iOS yet, same disclosed-trim reasoning Phase 9 used for
`reviewEventsForTopic`. Android's study-plan launch/session integration
(`sessionId`/`masteryBeforePercent`, jumping straight into
`TakeExamActivity`, the post-submission confidence prompt) is
correspondingly absent too.

### Phase 10 UI test

One new combined case in `VisionIOSUITests.swift`,
`test_takingAHandAuthoredExamAndGeneratingFromMaterial`, covering two
real paths:

1. A fully hand-authored MCQ exam — created, saved, opened, answered
   correctly, and submitted — confirming the real results screen reads
   exactly "100% correct" with zero AI involved at any point (unlike
   Flashcards/Topics, Create Exam needs no cloud key configured at
   all, so this is a genuine full-credit proof, not just an
   honest-error path).
2. The same honest "Cloud AI isn't configured" proof already
   established for Rewrite Writer/Topics/Flashcards, exercised through
   Generate Mock Test against the same real seeded-and-processed
   fixture — confirming `ExamGenerator` routes through the identical
   `CloudAIProvider`/`StructuredAI` plumbing, not a parallel path.

`AppDatabase.swift`'s `v7_phase10` migration adds `examTest`,
`examQuestion`, `examAttempt`, and `examAnswer` to the same shared
`vision.sqlite`.

## Phase 9: Flashcards

Direct port of the standalone (non-study-plan-session) scope of
`Flashcard.kt`/`FlashcardScheduling`/`FlashcardDbHelper.kt`/
`FlashcardGenerationLogic.kt`/`FlashcardsActivity.kt`. Reached via a new
"Flashcards" entry in the overflow menu.

- **`Sources/VisionCore/FlashcardScheduling.swift`** (pure, real-verified
  without Xcode): the same Leitner-style schedule as desktop's
  `EduFlashcardStore.ts` (`INTERVAL_TIERS_DAYS = [1, 3, 7, 14, 30]`) —
  advances one tier per confident review, resets to tier 0 on "still
  learning."
- **`Sources/VisionCore/TopicTagging.swift`** (pure): closes a trim
  explicitly disclosed in Phase 8 — "deferred to Phase 9, where it has a
  real immediate consumer." Direct port of `TopicTagging.kt`'s shared
  "ask the AI to name the closest real extracted topic, resolve that
  name back to a real topicId, never trust an invented one" logic,
  decoupled from the GRDB-backed `Topic` record via a minimal pure
  `TopicRef` the same way `RawTopic` already is.
- **`Sources/VisionCore/FlashcardGenerationLogic.swift`** (pure): the
  real system instruction, 12,000-char bounding, 1–50 count clamping,
  and permissive JSON parsing (`RawFlashcard`), direct port of
  `FlashcardGenerationLogic.kt` — same real/pure split
  `TopicExtractionLogic`/`TopicExtractor` already established.
- **`App/FlashcardStore.swift`** (GRDB) + **`FlashcardGenerator.swift`**:
  real card storage, due-queue sorting (never-reviewed first, then
  shortest-interval first), and `markReviewed`'s real schedule update,
  plus the real AI call orchestration reusing the exact
  `StructuredAI`/`CloudAIProvider` plumbing `TopicExtractor` already
  proved reaches the real Anthropic/OpenAI APIs.
- **`App/FlashcardsView.swift`**: pick a real processed document,
  generate real cards from its real extracted text, review the real due
  queue (tap to flip, "Still learning"/"I know it"), see every real
  card's own review stats.

**Disclosed scope trim: Exams, Tutor, Performance, and Study Plan are
not ported.** The build plan bundles all five ("Flashcards, Exams,
Tutor, Performance, Study Plan") under one "Phase 9," but their real
combined Android source is ~3,000 lines — roughly double Phase 8's, and
Phase 8 alone took six real CI iterations to land. Android's own
dependency order requires real Flashcards/Exams data before
Performance's mastery calculation can honestly run, and Performance
before Study Plan can honestly build on it — building all five before
any of them is live-verified isn't the smallest real slice, the same
reasoning Phase 8 used to defer Android's "Study Material hub." Each
gets its own later phase instead.

Within what *is* built: `markReviewed` still writes real
`flashcardReviewEvent` rows (a core part of reviewing a card for real,
not built ahead of a need), but `FlashcardDbHelper.kt`'s
`reviewEventsForTopic` reader method isn't ported — its return type
depends on `MasteryEvent`, which belongs to Performance's own phase.
Android's study-plan session integration (`sessionId`/
`completeCurrentSession`/`StudySessionLogic`) is correspondingly absent
too, since Study Plan doesn't exist on iOS yet — this is the same plain,
standalone Flashcards experience Android itself has when reached outside
a study-plan session.

### Phase 9 UI test

One new case in `VisionIOSUITests.swift`:
`test_generatingFlashcardsFromASeededMaterial` — processes the same real
seeded fixture Phase 8's test uses, confirms the real document picker
shows it once processed, attempts real flashcard generation with no AI
provider configured (the same honest "Cloud AI isn't configured"
message already proved for Rewrite Writer and Topics — `FlashcardGenerator`
routes through the identical plumbing), and confirms the real "nothing
due"/"none yet" empty states render rather than fabricated cards.

`AppDatabase.swift`'s `v6_phase9` migration adds `flashcard` and
`flashcardReviewEvent` to the same shared `vision.sqlite`.

## Phase 8: My Materials (document import, extraction, AI topic extraction)

Direct port of the real slice of `MaterialsActivity.kt`/`MaterialsAdapter.kt`
the build plan names explicitly: "unlocks Flashcards/Exams/Tutor via
topic extraction." Reached via a new "My Materials" entry in the
overflow menu.

- **`Sources/VisionCore/StudyDocumentTypes.swift`** (pure): `StudyFileType`/
  `StudyDocumentStatus`, direct ports of the matching Kotlin enums.
- **`Sources/VisionCore/TopicExtractionLogic.swift`** + **`StructuredJSON.swift`**
  (pure, real-verified without Xcode via the standalone `swiftc` harness
  and `swift test`): the real system instruction, 12,000-char bounding,
  and permissive JSON parsing (`RawTopic`/`RawSubtopic`) ported from
  `TopicExtractionLogic.kt`, plus the fenced-```json-block extraction
  `StructuredAi.kt`'s `extractJsonText` does — pure prompt-building and
  response-parsing only, same real/pure split `CloudAIRequestBuilder`
  already established.
- **`App/DocumentExtractors.swift`**: real text extraction per file type.
  PDF via **PDFKit** — Apple's first-party framework, a genuine
  simplification over Android, which has no first-party text-layer API
  (`PdfRenderer` only rasterizes to bitmaps) and needs the third-party
  pdfbox-android library for this; iOS needs nothing extra. DOCX via a
  new **ZIPFoundation** dependency (iOS has no first-party zip-reading
  API, unlike Android's built-in `java.util.zip.ZipFile` — a real,
  disclosed extra dependency for exactly that gap, same reasoning as
  choosing GRDB over hand-rolled SQLite3 calls) plus Foundation's own
  `XMLParser` reading `word/document.xml` directly, as targeted as
  `DocxExtractor.kt`: no heading-style preservation, just the real full
  plain text. TXT trivially via `String(contentsOf:encoding:)`.
- **`App/DocumentImport.swift`**: real file copy into app storage
  (`startAccessingSecurityScopedResource()` around it — iOS's own real
  equivalent of Android's `content://` Uri permission grant, with no
  Android analog needed since `ContentResolver.openInputStream` handles
  that implicitly) and real per-stage honest failure during processing —
  an unreadable file or one with no real text layer ends in `.failed`
  with a specific, real reason, never a silently-empty success.
- **`App/StudyDocumentStore.swift`** (GRDB) + **`TopicStore.swift`** (GRDB):
  deliberately narrower than Android's own final schema — no taxonomy
  (level/grade/category/subject/resourceType/year/language) or
  `offlineReadyAt` columns yet; those belong to Android's separate,
  bigger "Study Material hub" this phase does not port (see below).
- **`App/StructuredAI.swift`** + **`TopicExtractor.swift`**: the real AI
  call orchestration — direct port of `StructuredAi.kt`'s try-each-
  provider/retry-once-on-bad-JSON logic, using the same `CloudAIProvider`
  plumbing Phase 5 already proved reaches the real Anthropic/OpenAI APIs.
- **`App/MaterialsView.swift`**: upload, real text extraction (tap
  Process/Retry), and tap-to-reveal AI topic extraction (first tap shows
  cached topics or runs one real AI call; second tap just collapses the
  cached result) — direct port of `MaterialsActivity.kt`'s
  `toggleTopics()`.

**Disclosed scope trim: Android's "Study Material hub" is not ported.**
`StudyMaterialActivity.kt` — a separate, later-added, substantially
bigger feature (taxonomy tagging, browse/search, offline-ready marking,
a folded-in spaced-repetition review tab) — is deliberately left for its
own later phase, not bundled into this one. The build plan's own
one-line Phase 8 description ("unlocks Flashcards/Exams/Tutor via topic
extraction") maps directly onto `MaterialsActivity.kt`'s real scope, not
`StudyMaterialActivity.kt`'s.

**Disclosed test-seam: a `-UITestSeedMaterial` launch argument.**
Driving iOS's own system file-picker sheet (`.fileImporter`) reliably
from XCUITest is a known, genuine platform limitation (the Files app's
own UI, not this app's) — real projects widely report this as close to
undriveable. So the upload step itself stays live-verified by hand, not
by CI; a UI test launching with `-UITestSeedMaterial` instead gets one
real fixture file genuinely copied onto disk and one real
`StudyDocument` row inserted at app launch
(`MainBrowserView.seedMaterialsFixtureIfRequested()`) — the same real
state `DocumentImport.importFile` would have produced had the picker
actually been driven. Everything downstream of that real upload —
processing, topic extraction, deletion — is still exercised for real.

### The real bug trail — six CI iterations, the longest of any phase

Documented in full rather than squashed, same convention as Phase 1's
"seven real bugs" and Phase 7's toolbar-overflow saga:

1. **A plain tap-before-wait race** in the new test — it tapped
   `btnProcessDocument_ui-test-fixture` without first waiting for its
   existence, unlike every other test in the suite. Fixed by adding the
   wait.
2. **A worse version of Phase 6/7's accessibility-identifier quirk.**
   The row's container `VStack` carried its own `.accessibilityIdentifier`
   (`materialRow_*`); a real captured `.xcresult` dump showed this
   didn't just leak onto plain `StaticText` leaves (the Phase 6/7
   pattern) — it *overwrote* `btnProcessDocument_*`/`btnDeleteDocument_*`'s
   own explicit identifiers, both reported back carrying the row's
   identifier instead of their own. Fixed by removing the container-level
   identifier and giving the title its own (`materialTitle_*`).
3. **A genuine actor-isolation bug.** `process()`'s `Task.detached`
   closure read `studyDocumentStore` (a MainActor-isolated SwiftUI
   property) directly — a real Swift 6 concurrency-checker warning, not
   a style nit. Fixed by capturing it into a plain local before
   detaching. This was a real, worthwhile fix on its own merits, but
   didn't resolve the still-failing test.
4. **Suspected (and ruled out) CI-runner slowness.** Widened the test's
   own timeouts after an unrelated, previously-stable test also failed
   in the same run with a similarly inflated duration — a pattern that
   *had* correctly identified pure infrastructure flakiness twice
   before in this project (Phase 7's toolbar fix, and a Phase 7 README
   commit). This time it didn't help: the exact same failure recurred.
5. **The real root cause**, found only by downloading the `.xcresult`
   twice and decoding the app's own real console output (NSLog tracing
   added specifically to settle it, after two targeted fixes failed to):
   `process(_ doc:)`'s `setStatus(doc.id, .processing)` mutates
   `documents` — and the "Process"/"Retry" button only renders while
   `doc.status` is `.uploaded`/`.failed`, so this removes that same
   button from the view hierarchy while its own tap gesture was still
   being finalized. The Delete button — the only other real sibling in
   that `HStack` — shifted into the vacated screen position in time to
   catch a follow-up touch meant for the just-removed button, genuinely
   deleting the seeded fixture's real DB row *and* its real file's
   parent directory. That's why the document appeared to "vanish" and
   the extraction appeared to "fail with file not found" — both were
   real, correct symptoms of a real deletion, not bugs in the deleted
   code paths themselves.
6. **The actual fix**: rather than chase the exact timing further (a
   first attempt deferring the mutation via `DispatchQueue.main.async`
   did *not* resolve it, disproving that specific theory), the hazard
   class was removed entirely — Delete moved from an always-visible tap
   button sharing an `HStack` with the conditionally-rendered Process
   button to a real `.swipeActions` destructive action, matching
   `HistoryView.swift`'s own already-established pattern in this
   codebase. A swipe gesture can't land on a tap target that shifted
   into a different button's old position, regardless of timing.

### Phase 8 UI test

One new case in `VisionIOSUITests.swift`:
`test_processingAndExtractingTopicsForASeededMaterial` — processes a
real seeded `.txt` fixture (real `TxtExtractor` against a real file),
confirms the real "Processed" status, attempts real topic extraction
with no AI provider configured (confirming the same honest "Cloud AI
isn't configured" message `test_rewriteWithNoProviderConfigured_showsHonestError`
already proved for Rewrite Writer — `TopicExtractor` routes through the
identical `CloudAIProvider` plumbing, not a parallel path), then swipes
to delete the fixture and confirms its real row is gone.

`AppDatabase.swift`'s `v5_phase8` migration adds `studyDocument` and
`topic` to the same shared `vision.sqlite`. `project.yml` adds
ZIPFoundation as a second real SPM dependency alongside GRDB.

## Phase 7: Rewards

Direct port of `RewardRules.kt`/`RewardEligibility.kt`/`RewardEngine.kt`/
`RewardDbHelper.kt` — reached via a new "Rewards" entry in the overflow
menu (see below).

- **`Sources/VisionCore/RewardRules.swift`** and **`RewardEligibility.swift`**
  (pure, real-verified without Xcode via the standalone `swiftc` harness
  and `swift test`): the real category/event/points/level scale, carried
  over as-is from the desktop app's `rewardRules.ts`, and the dedupe/
  daily-limit eligibility gate every award passes through.
  `RewardEventType` only lists the 6 real event types whose trigger
  exists on iOS right now (`OFFLINE_PREP`, `TASK_COMPLETED`,
  `HEALTHY_BREAK`, `DIGITAL_BALANCE`, `FOCUS_SESSION_COMPLETED`,
  `WEEKLY_CONSISTENCY`) — Android's education-related cases
  (`EDU_TEST_COMPLETED`, `STUDY_PLAN_TASK_COMPLETED`,
  `STUDY_SESSION_COMPLETED`, `EDU_MASTERY_MILESTONE`) are left out for
  exactly the reason `RewardRules.kt`'s own comment documents leaving
  them out through Android's own Phase 18: no education feature exists
  yet to genuinely trigger them.
- **`App/RewardStore.swift`** (GRDB) + **`RewardEngine.swift`**: the real
  points ledger and the eligibility-checked award gate, wired into the
  four real triggers that already exist — `OfflineSaver`'s successful
  save (`OFFLINE_PREP`), `TaskStore.complete`'s real one-way completion
  (`TASK_COMPLETED`), `WellbeingActions.takeBreak` gated on 10+ real
  continuous minutes (`HEALTHY_BREAK` + `DIGITAL_BALANCE`), and
  `FocusManager.onSessionEnd` gated on `completedNaturally` and 15+
  planned minutes (`FOCUS_SESSION_COMPLETED`) — plus `WEEKLY_CONSISTENCY`
  awarded automatically by `RewardEngine` itself as a side effect of any
  other award. `availableBalance()` currently always equals `total()`:
  the real formula is `total() − redemption spend`, and there's
  genuinely never any spend yet since Redeem isn't ported (see below) —
  a real, correct value for the real current state, not a placeholder.
- **`App/RewardsView.swift`**: real level/points/balance, this-week-by-
  category stats, a weekly insight banner, "how you earn points," and
  recent activity — every number from `RewardStore`, nothing seeded.
- Closed a Phase 6 disclosed trim: `AdvisorView`'s real "This Week"
  section (points/healthy-breaks/focus-sessions this week) was left out
  then because it depended on reward data that didn't exist yet. It
  drops Android's own "🎓 Learning completed" row for the same reason
  `RewardEventType` drops `EDU_TEST_COMPLETED` — no education feature
  exists on iOS yet to generate any.

**Disclosed scope trim: Redeem is not ported.** Android's Redeem feature
(`RedeemActivity.kt`, `RedemptionDbHelper.kt`, `RewardCatalogRemote.kt`,
`FirestoreRestClient.kt`) spends real points against a shared catalog
synced from a real Firestore backend over anonymous auth
(`FirebaseAnonAuth`) and a real `FirebaseConfig` project. None of that
infrastructure exists for iOS — there's no Firebase project config, no
anonymous-auth flow, nothing to verify a real REST call against. Porting
it now would mean either fabricating unverifiable network code or faking
the whole feature, both against this project's basic rule. Deferred to a
later phase, once real Firebase project credentials exist to build and
verify against for real.

### A real toolbar-overflow bug, and the two more real bugs fixing it properly surfaced

The first CI run of this phase failed `test_historyRecordsRealNavigation`
and `test_privateTabDoesNotRecordHistory` with a real
`kAXErrorCannotComplete` trying to scroll `historyButton` into view — its
real captured frame had gone negative (off the left edge). The actual
cause wasn't cosmetic: `MainBrowserView`'s `secondaryToolbar` had grown to
8 always-visible icon buttons across Phases 1–7, and this was simply the
push that didn't fit anymore. Reading `MainActivity.kt`'s real
`showOverflowMenu()` showed this was always an architectural mismatch —
Android's entire toolbar is just Back/Forward/address bar/Bookmark/tab-
count plus one real "⋮" button opening a popup with every other action;
it never grows a second always-visible row no matter how many features
get added. iOS had drifted from that since Phase 1. Patching the symptom
(e.g. wrapping the row in a horizontal `ScrollView`) would have just
deferred the exact same break to Phase 8 or 9, so this was fixed by
actually matching the real architecture: one SwiftUI `Menu` replacing
`secondaryToolbar` entirely, and every affected UI test rewritten to open
it first.

That fix surfaced two more real, independent bugs, each found through a
genuine CI failure and fixed with evidence, not a guess:

1. **A SwiftUI `Menu` tap quirk.** The very next run failed tapping
   `moreMenuButton` with the same `kAXErrorCannotComplete` — but a real
   captured `.xcresult` accessibility-tree dump (this project's
   established Zstandard-blob forensics technique, same one Phase 1 and
   Phase 6 used) showed the button's frame was genuinely fully on-screen
   (`{402.3, 76.7}`–`{422.0, 95.7}` inside a real 430pt-wide window).
   XCUITest's default `.tap()` was failing on its own auto-scroll-into-
   view step, apparently confused by `Menu`'s nested Button-inside-Button
   accessibility structure — not an off-screen bug at all. Fixed by
   tapping via raw coordinate instead, which skips that failing step.
2. **A real leaked `Timer`.** With that fixed, 14 of 15 tests passed; the
   one that opens `FocusView` twice in a single run (start a session,
   close it, reopen it to clean up the test's own blocklist entry) hit a
   genuine ~60-real-second stall waiting for the app to report idle.
   `FocusView`'s countdown was a plain `let tick = Timer.publish(every: 1,
   on: .main, in: .common).autoconnect()` — `.autoconnect()` starts a
   real, already-running `Timer` the instant it's created, and a plain
   stored `let` gets reconstructed (reconnecting a brand-new real Timer)
   on every body re-evaluation of the view struct. Opening the view twice
   gave this real leak enough opportunity to compound into a measurable
   stall. Fixed by making it `@State`, so SwiftUI preserves the same
   publisher instance across re-renders for that view's identity instead
   of reconnecting a new one each time.

### Phase 7 UI tests

Two new cases in `VisionIOSUITests.swift`:
- `test_savingOfflineAwardsARealRewardEvent` — a real offline save shows
  up as a real recent-activity row in Rewards, asserted on the specific
  saved-page note text rather than a point total so it stays correct
  regardless of points already earned by other tests or earlier runs.
- `test_completingATaskAwardsARealRewardEvent` — same proof for
  completing a real task.

`AppDatabase.swift`'s `v4_phase7` migration adds `rewardEvent` to the same
shared `vision.sqlite`.

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
- `MainBrowserView.swift` — one toolbar row (back/forward/address bar/bookmark/tab count) plus a real overflow `Menu` for every other action, with the 8 education screens under a real nested "Education" submenu — matching `MainActivity.kt`'s own `showOverflowMenu()` architecture exactly (both the original single-popup shape from Phase 7, and its own later Education/Settings accordion restructuring once that popup grew too large, see Phase 16's bug writeup for why iOS hit the same wall and matched the same real fix); hosts the active tab via `ActiveTabContent`
- `WebViewRepresentable.swift` — `UIViewRepresentable` wrapping one `WKWebView` per tab; real history recording + real `WKDownloadDelegate` handling
- `BrowserTab.swift` — mirrors `Tab.kt` (id, title, url, isNewTab, isPrivate)
- `TabManager.swift` — mirrors `MainActivity.kt`'s `tabs`/`activeTabIndex` + create/switch/close/navigate/openOfflineFile, delegates close-index math to `VisionCore.TabIndexing`
- `AppDatabase.swift` — GRDB `DatabaseQueue` + migrator (`v1_bookmarks`, `v2_phase2`, `v3_phase6`, `v4_phase7`, `v5_phase8`, `v6_phase9`, `v7_phase10`, `v8_phase11`, `v9_phase13`, `v10_phase16`, `v11_phase18`) — no new migration for Phase 17 (VISION Ready is a pure read-aggregate over existing `bookmark`/`offlineItem` rows, same reasoning as Phase 12's Performance)
- `BookmarkStore.swift` / `HistoryStore.swift` / `DownloadStore.swift` / `OfflineStore.swift` — GRDB ports of the matching `*DbHelper.kt`; `OfflineStore` also has the real per-item category reassignment (Phase 18)
- `StudyReviewStore.swift` — GRDB I/O wrapping the pure `VisionCore.StudyReviewLogic`, port of `StudyReviewDbHelper.kt`
- `OfflineSaver.swift` — real `createWebArchiveData` capture + file write
- `KeychainStore.swift` / `AiSettings.swift` — real Keychain-backed AI key storage, port of `AiSettings.kt`
- `AppSettings.swift` — `UserDefaults`/`@AppStorage`-backed theme + search engine (Phase 3) + offline storage limit (Phase 17), port of `VisionSettings.kt`'s matching slice
- `ConnectivityMonitor.swift` — real `NWPathMonitor`-backed online/offline state, port of `ConnectivityUtil.kt`
- `CloudAIProvider.swift` — real `URLSession` networking for the two cloud AI providers, port of `CloudAiProvider.kt`
- `RewriteWriter.swift` — real OpenAI-then-Anthropic rewrite orchestration, port of `RewriteWriter.kt`
- `FocusManager.swift` / `FocusStore.swift` / `FocusBlockedPage.swift` — real Focus Mode session timer, GRDB blocklist/session history, and the local blocked-page HTML, port of `FocusManager.kt`/`FocusDbHelper.kt`/`FocusBlockedPage.kt`
- `TaskStore.swift` — GRDB port of `TaskDbHelper.kt`
- `WellbeingManager.swift` / `WellbeingStore.swift` / `WellbeingActions.swift` — in-process tracking + GRDB break/site-visit log, port of `WellbeingManager.kt`/`WellbeingDbHelper.kt`/`WellbeingActions.kt`
- `FaviconLoader.swift` — real `google.com/s2/favicons` fetch + in-memory cache, used by Focus Mode's blocklist rows
- `RewardStore.swift` / `RewardEngine.swift` — real GRDB points ledger + the eligibility-checked award gate, port of `RewardDbHelper.kt`/`RewardEngine.kt`
- `DocumentExtractors.swift` — real PDFKit/ZIPFoundation+XMLParser/plain-text extraction, port of `PdfExtractor.kt`/`DocxExtractor.kt`/`TxtExtractor.kt`
- `DocumentImport.swift` — real file copy + per-stage honest processing failure, port of `DocumentImport.kt`
- `StudyDocumentStore.swift` / `TopicStore.swift` — GRDB ports of `StudyDocumentDbHelper.kt` / `TopicDbHelper.kt`; `StudyDocumentStore` carries the full real taxonomy/offlineReadyAt columns as of Phase 18, not just the `MaterialsActivity.kt` slice
- `StructuredAI.swift` / `TopicExtractor.swift` — the real AI call orchestration, port of `StructuredAi.kt` + the networking half of `TopicExtractionLogic.kt`
- `FlashcardStore.swift` / `FlashcardGenerator.swift` — real card storage, due-queue sorting (never-reviewed first, then shortest-interval first), and `markReviewed`'s real schedule update, plus the real AI call orchestration reusing the exact `StructuredAI`/`CloudAIProvider` plumbing `TopicExtractor` already proved reaches the real Anthropic/OpenAI APIs
- `ExamStore.swift` / `ExamGenerator.swift` / `ShortAnswerMarker.swift` — real test/question/attempt/answer GRDB storage, instant local MCQ/true-false marking, and the real AI orchestration for AI-generated tests and batched short-answer marking, reusing the same `StructuredAI`/`CloudAIProvider` plumbing
- `TutorStore.swift` / `TutorAI.swift` — real session/message GRDB storage and the real free-text AI call loop behind AI Tutor
- `PerformanceCalculator.swift` — real per-topic mastery aggregation, orchestrating `VisionCore.MasteryEngine` over real flashcard-review/exam-answer events
- `StudyPlanStore.swift` / `StudySessionManager.swift` / `SessionConfidencePrompt.swift` — real plan/item/session GRDB storage, the real session-lifecycle orchestration behind My Week's "Start session", and the shared post-session confidence prompt reused by Flashcards/Exams
- `PaperReviewer.swift` — the real AI call orchestration behind Paper Review
- `HelpContent.swift` — real, static in-app documentation data
- `ChatSessionStore.swift` / `ChatAI.swift` — real multi-session GRDB storage and the real free-text AI call loop behind Ask VISION chat
- `VisionReadyView.swift` — real Offline Readiness card (reads `VisionCore.ReadinessLogic` over `BookmarkStore`/`OfflineStore`) plus honest disabled states for Keeping Pages Up to Date/Sports/Maps, port of `VisionReadyActivity.kt`
- `StudyMaterialView.swift` — the real taxonomy browser/tagging/Review screen, port of `StudyMaterialActivity.kt`
- `BookmarksView.swift` — the real dedicated manage-bookmarks screen, port of `BookmarksActivity.kt`, found as a gap during a cross-source sweep
- `NewTabView.swift` / `HistoryView.swift` / `DownloadsView.swift` / `OfflineLibraryView.swift` / `SettingsView.swift` / `RewriteView.swift` / `FocusView.swift` / `TasksView.swift` / `AdvisorView.swift` / `RewardsView.swift` / `MaterialsView.swift` / `FlashcardsView.swift` / `ExamsView.swift` / `CreateExamView.swift` / `GenerateExamView.swift` / `TakeExamView.swift` / `TutorView.swift` / `PerformanceView.swift` / `StudyPlanView.swift` / `PaperReviewView.swift` / `HelpView.swift` / `AskVisionView.swift` — real list/empty-state/settings/rewrite/focus/tasks/advisor/rewards/materials/flashcards/exams/tutor/performance/study-plan/paper-review/help/ask-vision screens
- `DesignSystem.swift` — same component list and color tokens as `DesignSystem.kt`, ported to `@ViewBuilder` functions; drawable XML collapses into inline SwiftUI modifiers (disclosed simplification, noted in-file)

**`UITests/`** — `VisionIOSUITests.swift`, the real behavioral verification described above.

`project.yml` (XcodeGen spec) generates the actual `.xcodeproj` (app target
+ `VisionIOSUITests` target + a `VisionIOS` scheme wiring both) in CI —
there's no hand-crafted `.pbxproj` in this repo, it's regenerated fresh
every run.

## Explicitly NOT built yet (disclosed scope trims, not oversights)

Profile/credentials/offline-AI-model/memory settings, on-device local
model fallback, and Redeem. Redeem specifically needs real Firebase
project credentials and anonymous-auth infrastructure this repo
doesn't have — see Phase 7's own writeup for why that's a disclosed
trim rather than fabricated.

**Autofill** (the overflow menu's `action_autofill`, filling a saved
login into the active tab's form) isn't ported — it depends entirely
on real credential storage (`CredentialDbHelper.kt`/`CredentialCrypto.kt`
on Android), which falls under the "credentials" deferral above. Found
as a genuine gap during a cross-source sweep against Android's own
`MainActivity.kt`; building it for real means storing actual user
passwords, a bigger, security-sensitive undertaking than a quick fix,
so it's named here explicitly rather than left silently bundled into
the vaguer "credentials" line.

Within VISION Ready specifically: no real background-refresh worker
exists to back a working "Keeping Pages Up to Date" toggle (Smart
Cache — disclosed since the Phase 2 migration comment), no live sports
data provider, and no offline maps — all three show as honest disabled
states rather than fabricated ones. See Phase 17's own writeup.

Within Ask VISION chat specifically: Android's voice input, chat
export, date-grouped/searchable session history, and per-message
"Remember this"/"Save for offline" quick actions aren't ported — each
tied to a real capability this app doesn't have yet (a Memory feature,
or a hidden-`WKWebView` live-page-fetch, `FetchLivePage.kt` — loads an
arbitrary URL in an off-screen `WKWebView` and reads
`document.body.innerText`, a genuinely trickier capability deliberately
left for its own phase).

## Next steps

Phase 18 (Study Material hub) is done, and a real cross-source sweep
against `MainActivity.kt`'s own menu closed the one gap worth closing
right now (the dedicated Bookmarks screen). Every screen from the
build plan's original roadmap — plus everything real the overflow menu
itself points to — is now built except Redeem (hard-blocked on real
Firebase project credentials and anonymous-auth infrastructure this
repo doesn't have) and Autofill (needs real credential storage, a
bigger, security-sensitive undertaking). Confirm before starting
either, or decide the port is otherwise complete.

**If local Xcode ever exists on this machine**: `xcodegen generate`, open
`VisionIOS.xcodeproj`, and everything here still works locally too — CI
was the necessary path given no Xcode locally, not a permanent substitute
for it.
