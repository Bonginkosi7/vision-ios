import XCTest
@testable import VisionCore

/// AnalyticsEvent's own doc comment flags the real risk this file guards
/// against: a typo'd name silently dropped by the server allowlist. A
/// second, related real risk this test catches instead: two different
/// constants accidentally sharing the same string value, which would
/// silently conflate two genuinely different events server-side.
final class AnalyticsEventTests: XCTestCase {
    func test_everyEventNameIsUnique() {
        let names = [
            AnalyticsEvent.appInstalled, AnalyticsEvent.appFirstOpened, AnalyticsEvent.appOpened,
            AnalyticsEvent.onboardingStarted, AnalyticsEvent.onboardingCompleted,
            AnalyticsEvent.browserOpened, AnalyticsEvent.newTabOpened,
            AnalyticsEvent.offlineLibraryOpened, AnalyticsEvent.resourceSavedOffline,
            AnalyticsEvent.resourceDownloadStarted, AnalyticsEvent.resourceDownloadCompleted,
            AnalyticsEvent.resourceOpenedOffline, AnalyticsEvent.offlineModeEntered,
            AnalyticsEvent.offlineModeExited, AnalyticsEvent.storageManagerOpened,
            AnalyticsEvent.offlineLoadSucceeded, AnalyticsEvent.offlineLoadFailed,
            AnalyticsEvent.focusModeStarted, AnalyticsEvent.focusModeCompleted,
            AnalyticsEvent.wellbeingAdvisorShown, AnalyticsEvent.wellbeingBreakTaken,
            AnalyticsEvent.educationOpened, AnalyticsEvent.gradeSelected, AnalyticsEvent.subjectSelected,
            AnalyticsEvent.contentPackOpened, AnalyticsEvent.contentPackDownloaded,
            AnalyticsEvent.contentPackUpdated, AnalyticsEvent.studySessionReviewed,
            AnalyticsEvent.rewardEventEarned, AnalyticsEvent.rewardsOpened,
            AnalyticsEvent.settingsOpened,
            AnalyticsEvent.aiQuerySubmitted, AnalyticsEvent.livePageFetchSucceeded,
            AnalyticsEvent.memoryFactAdded, AnalyticsEvent.memoryFactRemoved,
            AnalyticsEvent.rewriteGenerated, AnalyticsEvent.eduPaperReviewed, AnalyticsEvent.localModelDownloaded,
            AnalyticsEvent.eduDocumentUploaded, AnalyticsEvent.eduDocumentProcessed,
            AnalyticsEvent.eduFlashcardsGenerated, AnalyticsEvent.eduFlashcardReviewed,
            AnalyticsEvent.eduMocktestGenerated, AnalyticsEvent.eduMocktestCustomCreated,
            AnalyticsEvent.eduMocktestSubmitted, AnalyticsEvent.eduTutorQuestionAsked,
            AnalyticsEvent.eduLessonUploaded, AnalyticsEvent.eduLessonYoutubeAdded,
            AnalyticsEvent.eduLessonTranscribed, AnalyticsEvent.eduLessonDocumentAttached,
            AnalyticsEvent.eduStudyplanGenerated, AnalyticsEvent.eduStudySessionCompleted,
        ]

        XCTAssertEqual(names.count, Set(names).count, "a duplicate event name would silently conflate two different events server-side")
        XCTAssertTrue(names.allSatisfy { !$0.isEmpty })
    }
}
