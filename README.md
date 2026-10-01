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
- `MainBrowserView.swift` — one toolbar row (back/forward/address bar/bookmark/tab count) plus a single real overflow `Menu` for every other action, matching `MainActivity.kt`'s own `showOverflowMenu()` architecture (see Phase 7's bug writeup for why); hosts the active tab via `ActiveTabContent`
- `WebViewRepresentable.swift` — `UIViewRepresentable` wrapping one `WKWebView` per tab; real history recording + real `WKDownloadDelegate` handling
- `BrowserTab.swift` — mirrors `Tab.kt` (id, title, url, isNewTab, isPrivate)
- `TabManager.swift` — mirrors `MainActivity.kt`'s `tabs`/`activeTabIndex` + create/switch/close/navigate/openOfflineFile, delegates close-index math to `VisionCore.TabIndexing`
- `AppDatabase.swift` — GRDB `DatabaseQueue` + migrator (`v1_bookmarks`, `v2_phase2`, `v3_phase6`, `v4_phase7`, `v5_phase8`, `v6_phase9`, `v7_phase10`)
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
- `RewardStore.swift` / `RewardEngine.swift` — real GRDB points ledger + the eligibility-checked award gate, port of `RewardDbHelper.kt`/`RewardEngine.kt`
- `DocumentExtractors.swift` — real PDFKit/ZIPFoundation+XMLParser/plain-text extraction, port of `PdfExtractor.kt`/`DocxExtractor.kt`/`TxtExtractor.kt`
- `DocumentImport.swift` — real file copy + per-stage honest processing failure, port of `DocumentImport.kt`
- `StudyDocumentStore.swift` / `TopicStore.swift` — GRDB ports of the `MaterialsActivity.kt`-used slice of `StudyDocumentDbHelper.kt` / `TopicDbHelper.kt`
- `StructuredAI.swift` / `TopicExtractor.swift` — the real AI call orchestration, port of `StructuredAi.kt` + the networking half of `TopicExtractionLogic.kt`
- `FlashcardStore.swift` / `FlashcardGenerator.swift` — real card storage, due-queue sorting (never-reviewed first, then shortest-interval first), and `markReviewed`'s real schedule update, plus the real AI call orchestration reusing the exact `StructuredAI`/`CloudAIProvider` plumbing `TopicExtractor` already proved reaches the real Anthropic/OpenAI APIs
- `ExamStore.swift` / `ExamGenerator.swift` / `ShortAnswerMarker.swift` — real test/question/attempt/answer GRDB storage, instant local MCQ/true-false marking, and the real AI orchestration for AI-generated tests and batched short-answer marking, reusing the same `StructuredAI`/`CloudAIProvider` plumbing
- `NewTabView.swift` / `HistoryView.swift` / `DownloadsView.swift` / `OfflineLibraryView.swift` / `SettingsView.swift` / `RewriteView.swift` / `FocusView.swift` / `TasksView.swift` / `AdvisorView.swift` / `RewardsView.swift` / `MaterialsView.swift` / `FlashcardsView.swift` / `ExamsView.swift` / `CreateExamView.swift` / `GenerateExamView.swift` / `TakeExamView.swift` — real list/empty-state/settings/rewrite/focus/tasks/advisor/rewards/materials/flashcards/exams screens
- `DesignSystem.swift` — same component list and color tokens as `DesignSystem.kt`, ported to `@ViewBuilder` functions; drawable XML collapses into inline SwiftUI modifiers (disclosed simplification, noted in-file)

**`UITests/`** — `VisionIOSUITests.swift`, the real behavioral verification described above.

`project.yml` (XcodeGen spec) generates the actual `.xcodeproj` (app target
+ `VisionIOSUITests` target + a `VisionIOS` scheme wiring both) in CI —
there's no hand-crafted `.pbxproj` in this repo, it's regenerated fresh
every run.

## Explicitly NOT built yet (disclosed scope trims, not oversights)

Profile/credentials/offline-AI-model/memory/storage settings, on-device
local model fallback, the Ask VISION chat, the remaining education
screens (Tutor, Performance, Study Plan, Paper Review), Android's
separate "Study Material hub" (taxonomy tagging, browse/search,
offline-ready marking, folded-in spaced-repetition review — a distinct,
bigger feature than My Materials, left for its own later phase),
Redeem, VISION Ready, and Help. Redeem specifically needs real Firebase
project credentials and anonymous-auth infrastructure this repo doesn't
have — see Phase 7's own writeup for why that's a disclosed trim rather
than fabricated. Sequencing for the rest is in the build plan's Phase
11–12 roadmap, itself re-scoped from the original bundled "Phase 9"
once Flashcards and Exams shipped as their own slices — Tutor/
Performance/Study Plan are now each their own future phase rather than
one bundle.

## Next steps

Phase 10 (Exams) is done. Flashcards and Exams between them now supply
the real data Android's own Performance (mastery calculation) needs,
so Performance looks like the natural next slice by that dependency
order — though Tutor has no such dependency and could just as
reasonably come first, since it's a self-contained conversational
feature. That's a suggestion, not a decision already made; confirm
before starting either.

**If local Xcode ever exists on this machine**: `xcodegen generate`, open
`VisionIOS.xcodeproj`, and everything here still works locally too — CI
was the necessary path given no Xcode locally, not a permanent substitute
for it.
