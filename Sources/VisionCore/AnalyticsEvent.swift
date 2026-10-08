/// Event names VISION is allowed to send to the analytics backend — a
/// direct Swift port of desktop's analyticsEvents.ts (already ported once
/// to Android's AnalyticsEvent.kt), kept in lockstep with the actual
/// security boundary: the vision-analytics-backend project's own
/// `src/events/allowlist.js`, which rejects anything not on its list no
/// matter what a client sends, and strips any property key outside each
/// event's own declared schema there. This file just keeps iOS call sites
/// from typo'ing a name that would silently be dropped server-side — it
/// carries no property-schema knowledge of its own, since the server is
/// the one place that's actually enforced.
///
/// Most names below have no real iOS call site yet — this phase ports the
/// analytics client infrastructure itself (queueing, flushing, the one
/// real app-lifecycle event this type already fires on its own); wiring
/// every screen's own track() call is separate follow-up scope, same as
/// Android's own AI/education names sat unused here until their own
/// phases landed. Kept here anyway, unused, for the same reason desktop's
/// own file keeps names a client hasn't wired up yet: so the constant
/// already exists, correctly spelled, the day a real call site for it is
/// added, rather than being invented from scratch then.
public enum AnalyticsEvent {
    public static let appInstalled = "app_installed"
    public static let appFirstOpened = "app_first_opened"
    public static let appOpened = "app_opened"
    public static let onboardingStarted = "onboarding_started"
    public static let onboardingCompleted = "onboarding_completed"

    public static let browserOpened = "browser_opened"
    public static let newTabOpened = "new_tab_opened"

    public static let offlineLibraryOpened = "offline_library_opened"
    public static let resourceSavedOffline = "resource_saved_offline"
    public static let resourceDownloadStarted = "resource_download_started"
    public static let resourceDownloadCompleted = "resource_download_completed"
    public static let resourceOpenedOffline = "resource_opened_offline"
    public static let offlineModeEntered = "offline_mode_entered"
    public static let offlineModeExited = "offline_mode_exited"
    public static let storageManagerOpened = "storage_manager_opened"
    public static let offlineLoadSucceeded = "offline_load_succeeded"
    public static let offlineLoadFailed = "offline_load_failed"

    public static let focusModeStarted = "focus_mode_started"
    public static let focusModeCompleted = "focus_mode_completed"
    public static let wellbeingAdvisorShown = "wellbeing_advisor_shown"
    public static let wellbeingBreakTaken = "wellbeing_break_taken"

    public static let educationOpened = "education_opened"
    public static let gradeSelected = "grade_selected"
    public static let subjectSelected = "subject_selected"
    public static let contentPackOpened = "content_pack_opened"
    public static let contentPackDownloaded = "content_pack_downloaded"
    public static let contentPackUpdated = "content_pack_updated"
    public static let studySessionReviewed = "study_session_reviewed"

    public static let rewardEventEarned = "reward_event_earned"
    public static let rewardsOpened = "rewards_opened"

    public static let settingsOpened = "settings_opened"

    public static let aiQuerySubmitted = "ai_query_submitted"
    public static let livePageFetchSucceeded = "live_page_fetch_succeeded"
    public static let memoryFactAdded = "memory_fact_added"
    public static let memoryFactRemoved = "memory_fact_removed"

    public static let rewriteGenerated = "rewrite_generated"
    public static let eduPaperReviewed = "edu_paper_reviewed"
    public static let localModelDownloaded = "local_model_downloaded"

    public static let eduDocumentUploaded = "edu_document_uploaded"
    public static let eduDocumentProcessed = "edu_document_processed"
    public static let eduFlashcardsGenerated = "edu_flashcards_generated"
    public static let eduFlashcardReviewed = "edu_flashcard_reviewed"
    public static let eduMocktestGenerated = "edu_mocktest_generated"
    public static let eduMocktestCustomCreated = "edu_mocktest_custom_created"
    public static let eduMocktestSubmitted = "edu_mocktest_submitted"
    public static let eduTutorQuestionAsked = "edu_tutor_question_asked"
    public static let eduLessonUploaded = "edu_lesson_uploaded"
    public static let eduLessonYoutubeAdded = "edu_lesson_youtube_added"
    public static let eduLessonTranscribed = "edu_lesson_transcribed"
    public static let eduLessonDocumentAttached = "edu_lesson_document_attached"
    public static let eduStudyplanGenerated = "edu_studyplan_generated"
    public static let eduStudySessionCompleted = "edu_study_session_completed"
}
