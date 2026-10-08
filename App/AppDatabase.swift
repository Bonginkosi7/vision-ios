import Foundation
import GRDB

/// The single shared SQLite database for this app — GRDB's DatabaseMigrator
/// is designed around one DatabaseQueue, and Android's own per-file
/// SQLiteOpenHelper split (23 separate .db files) was never a deliberate
/// design worth preserving, just SQLiteOpenHelper's default unit of
/// ownership (see vision-ios build plan). Each feature still gets its own
/// *Store.swift file and its own migration step, mirroring Android's
/// per-feature *DbHelper.kt convention at the file level even though the
/// underlying .sqlite file is shared.
enum AppDatabase {
    static let shared: DatabaseQueue = {
        do {
            let folderURL = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            let dbURL = folderURL.appendingPathComponent("vision.sqlite")
            let dbQueue = try DatabaseQueue(path: dbURL.path)
            try migrator.migrate(dbQueue)
            return dbQueue
        } catch {
            // A real database open/migration failure is unrecoverable for
            // this app (every screen depends on it) — fail loudly rather
            // than silently running with no persistence, which would look
            // like data loss to the user instead of a crash they can report.
            fatalError("Failed to open or migrate the app database: \(error)")
        }
    }()

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_bookmarks") { db in
            try db.create(table: "bookmark") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
                t.column("url", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v2_phase2") { db in
            // history: real log of every real navigation on a non-private
            // tab, direct port of HistoryDbHelper.kt's `history` table.
            try db.create(table: "historyEntry") { t in
                t.primaryKey("id", .text)
                t.column("url", .text).notNull()
                t.column("title", .text).notNull()
                t.column("visitedAt", .datetime).notNull()
            }
            try db.create(index: "idx_history_visitedAt", on: "historyEntry", columns: ["visitedAt"])

            // downloads: real record of files downloaded via WKDownload —
            // port of DownloadDbHelper.kt, minus `system_download_id`
            // (Android-specific: ties a row back to the OS's own
            // DownloadManager service; iOS has no separate download-manager
            // service to interoperate with — the WKDownload *is* the real
            // download, so there's nothing else to track here).
            try db.create(table: "downloadRecord") { t in
                t.primaryKey("id", .text)
                t.column("url", .text).notNull()
                t.column("filename", .text).notNull()
                t.column("mimeType", .text)
                t.column("state", .text).notNull()
                t.column("receivedBytes", .integer).notNull().defaults(to: 0)
                t.column("totalBytes", .integer).notNull().defaults(to: 0)
                t.column("startedAt", .datetime).notNull()
                t.column("completedAt", .datetime)
            }

            // offlineItem: real saved-page metadata, port of
            // OfflineDbHelper.kt's core columns. Smart Cache's refresh-
            // tracking columns (etag/lastModified/contentHash/
            // nextRefreshAt) and the recommendations table are deliberately
            // NOT ported in this phase — disclosed scope trim, see README —
            // there is no background refresh worker yet to use them.
            try db.create(table: "offlineItem") { t in
                t.primaryKey("id", .text)
                t.column("url", .text).notNull().unique()
                t.column("title", .text).notNull()
                t.column("contentPath", .text).notNull()
                t.column("sizeBytes", .integer).notNull()
                t.column("savedAt", .datetime).notNull()
                t.column("category", .text).notNull().defaults(to: "general")
            }
        }

        migrator.registerMigration("v3_phase6") { db in
            // Focus Mode — port of FocusDbHelper.kt's two tables.
            try db.create(table: "focusBlockedDomain") { t in
                t.primaryKey("domain", .text)
                t.column("addedAt", .datetime).notNull()
            }
            try db.create(table: "focusSession") { t in
                t.primaryKey("id", .text)
                t.column("startedAt", .datetime).notNull()
                t.column("endedAt", .datetime)
                t.column("plannedMinutes", .integer).notNull()
                t.column("blockedAttempts", .integer).notNull().defaults(to: 0)
            }

            // Tasks — port of TaskDbHelper.kt.
            try db.create(table: "task") { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("completedAt", .datetime)
            }

            // Wellbeing — port of WellbeingDbHelper.kt's two tables.
            try db.create(table: "wellbeingEvent") { t in
                t.primaryKey("id", .text)
                t.column("type", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "siteVisit") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("hostname", .text).notNull()
                t.column("visitedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v4_phase7") { db in
            // Rewards — port of RewardDbHelper.kt's reward_events table.
            // No redemptions table yet: Redeem (the Firestore-backed
            // spend side of this) needs real Firebase project credentials
            // this repo doesn't have — see README's disclosed scope trim.
            try db.create(table: "rewardEvent") { t in
                t.primaryKey("id", .text)
                t.column("type", .text).notNull()
                t.column("category", .text).notNull()
                t.column("points", .integer).notNull()
                t.column("note", .text).notNull()
                t.column("dedupeKey", .text)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_rewardEvent_createdAt", on: "rewardEvent", columns: ["createdAt"])
            try db.create(index: "idx_rewardEvent_dedupeKey", on: "rewardEvent", columns: ["dedupeKey"])
        }

        migrator.registerMigration("v5_phase8") { db in
            // My Materials — the slice of StudyDocumentDbHelper.kt's real
            // columns MaterialsActivity.kt actually uses. Deliberately
            // narrower than Android's own final schema at this point: no
            // taxonomy (level/grade/category/subject/resourceType/year/
            // language) or offlineReadyAt columns yet — those belong to
            // Android's separate, bigger "Study Material hub", added
            // later in v11_phase18 once that hub actually got built.
            try db.create(table: "studyDocument") { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("originalFilename", .text).notNull()
                t.column("fileType", .text).notNull()
                t.column("contentPath", .text).notNull()
                t.column("sizeBytes", .integer).notNull()
                t.column("status", .text).notNull()
                t.column("processingError", .text)
                t.column("extractedText", .text)
                t.column("createdAt", .datetime).notNull()
            }

            // Topics — port of TopicDbHelper.kt's real hierarchical
            // topic/subtopic structure.
            try db.create(table: "topic") { t in
                t.primaryKey("id", .text)
                t.column("documentId", .text).notNull()
                t.column("parentTopicId", .text)
                t.column("level", .integer).notNull()
                t.column("name", .text).notNull()
                t.column("summary", .text)
                t.column("ordinal", .integer).notNull()
            }
            try db.create(index: "idx_topic_documentId", on: "topic", columns: ["documentId"])
        }

        migrator.registerMigration("v6_phase9") { db in
            // Flashcards — port of FlashcardDbHelper.kt's two tables.
            try db.create(table: "flashcard") { t in
                t.primaryKey("id", .text)
                t.column("documentId", .text).notNull()
                t.column("front", .text).notNull()
                t.column("back", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("intervalTier", .integer).notNull().defaults(to: -1)
                t.column("reviewCount", .integer).notNull().defaults(to: 0)
                t.column("nextDueAt", .datetime)
                t.column("topicId", .text)
            }
            try db.create(table: "flashcardReviewEvent") { t in
                t.primaryKey("id", .text)
                t.column("flashcardId", .text).notNull()
                t.column("confident", .boolean).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_flashcardReviewEvent_flashcardId", on: "flashcardReviewEvent", columns: ["flashcardId"])
        }

        migrator.registerMigration("v7_phase10") { db in
            // Exams — port of ExamDbHelper.kt's four tables. No
            // mastery/topic-aggregate table: Android's own
            // markedAnswersForTopic (feeding MasteryEngine) isn't ported
            // either — Performance doesn't exist on iOS yet, same
            // disclosed trim as Phase 9's reviewEventsForTopic.
            try db.create(table: "examTest") { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("timeLimitMinutes", .integer)
                t.column("createdAt", .datetime).notNull()
                t.column("documentId", .text)
            }
            try db.create(table: "examQuestion") { t in
                t.primaryKey("id", .text)
                t.column("testId", .text).notNull()
                t.column("ordinal", .integer).notNull()
                t.column("type", .text).notNull()
                t.column("prompt", .text).notNull()
                t.column("optionsJSON", .text)
                t.column("correctAnswer", .text).notNull()
                t.column("explanation", .text)
                t.column("topicId", .text)
            }
            try db.create(index: "idx_examQuestion_testId", on: "examQuestion", columns: ["testId"])
            try db.create(table: "examAttempt") { t in
                t.primaryKey("id", .text)
                t.column("testId", .text).notNull()
                t.column("status", .text).notNull().defaults(to: "in_progress")
                t.column("startedAt", .datetime).notNull()
                t.column("submittedAt", .datetime)
                t.column("scorePercent", .double)
                t.column("expiresAt", .datetime)
            }
            try db.create(table: "examAnswer") { t in
                t.primaryKey("id", .text)
                t.column("attemptId", .text).notNull()
                t.column("questionId", .text).notNull()
                t.column("studentAnswer", .text).notNull()
                t.column("isCorrect", .boolean)
                t.column("feedback", .text)
                t.column("markedAt", .datetime)
            }
            try db.create(index: "idx_examAnswer_attemptId", on: "examAnswer", columns: ["attemptId"])
        }

        migrator.registerMigration("v8_phase11") { db in
            // AI Tutor — port of TutorDbHelper.kt's two tables. No
            // citedChunkIds/lessonId/timestampSeconds columns: this app
            // has no chunking/retrieval layer and no lessons feature, so
            // there's nothing real for those to hold.
            try db.create(table: "tutorSession") { t in
                t.primaryKey("id", .text)
                t.column("documentId", .text)
                t.column("title", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "tutorMessage") { t in
                t.primaryKey("id", .text)
                t.column("sessionId", .text).notNull()
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("groundedInDocument", .boolean)
                t.column("providerName", .text)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_tutorMessage_sessionId", on: "tutorMessage", columns: ["sessionId"])
        }

        migrator.registerMigration("v9_phase13") { db in
            // Study Plan — port of StudyPlanDbHelper.kt's three tables.
            try db.create(table: "studyPlan") { t in
                t.primaryKey("id", .text)
                t.column("documentId", .text)
                t.column("examDate", .datetime)
                t.column("generatedAt", .datetime).notNull()
                t.column("weekStartAt", .datetime).notNull()
            }
            try db.create(table: "studyPlanItem") { t in
                t.primaryKey("id", .text)
                t.column("planId", .text).notNull()
                t.column("dayOffset", .integer).notNull()
                t.column("topicId", .text)
                t.column("activityType", .text).notNull()
                t.column("targetCount", .integer).notNull()
                t.column("rationale", .text).notNull()
                t.column("completedAt", .datetime)
            }
            try db.create(index: "idx_studyPlanItem_planId", on: "studyPlanItem", columns: ["planId"])
            try db.create(table: "studySession") { t in
                t.primaryKey("id", .text)
                t.column("documentId", .text)
                t.column("topicId", .text)
                t.column("activityType", .text).notNull()
                t.column("planItemId", .text)
                t.column("startedAt", .datetime).notNull()
                t.column("endedAt", .datetime)
                t.column("confidenceRating", .integer)
            }
        }

        migrator.registerMigration("v10_phase16") { db in
            // Ask VISION chat — port of ChatSessionDbHelper.kt's two
            // tables, minus offlineUrl/liveSourceUrl/memoryCandidate
            // (no hidden-WKWebView fetch or Memory feature yet to
            // populate them — see README's disclosed scope trim).
            try db.create(table: "chatSession") { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "chatMessage") { t in
                t.primaryKey("id", .text)
                t.column("sessionId", .text).notNull()
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("category", .text)
                t.column("providerName", .text)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_chatMessage_sessionId", on: "chatMessage", columns: ["sessionId"])
        }

        migrator.registerMigration("v11_phase18") { db in
            // Study Material hub — the real taxonomy columns Phase 5's own
            // migration comment named as deferred ("those columns land in
            // their own migration if/when that hub gets built"), port of
            // StudyDocumentDbHelper.kt's Phase 23 schema addition.
            try db.alter(table: "studyDocument") { t in
                t.add(column: "level", .text)
                t.add(column: "grade", .text)
                t.add(column: "category", .text)
                t.add(column: "subject", .text)
                t.add(column: "resourceType", .text)
                t.add(column: "year", .integer)
                t.add(column: "language", .text)
                t.add(column: "offlineReadyAt", .datetime)
            }

            // Spaced review scheduling — port of StudyReviewDbHelper.kt's
            // two tables.
            try db.create(table: "studyReview") { t in
                t.primaryKey("offlineItemId", .text)
                t.column("intervalTier", .integer).notNull()
                t.column("reviewCount", .integer).notNull()
                t.column("nextDueAt", .datetime).notNull()
            }
            try db.create(table: "studyReviewEvent") { t in
                t.primaryKey("id", .text)
                t.column("offlineItemId", .text).notNull()
                t.column("confident", .boolean).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_studyReviewEvent_offlineItemId", on: "studyReviewEvent", columns: ["offlineItemId"])
        }

        migrator.registerMigration("v12_shortcuts") { db in
            // New Tab shortcuts — port of ShortcutDbHelper.kt's one table.
            // Default-row seeding happens in ShortcutStore itself (gated
            // on the table being empty), not here, since GRDB's migrator
            // only ever runs a migration once — unlike Android's onUpgrade
            // re-seed check, this can't re-seed a table a user has since
            // emptied out by removing every shortcut.
            try db.create(table: "shortcut") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
                t.column("url", .text).notNull()
                t.column("position", .integer).notNull()
            }
        }

        // Redeem (rewardCatalogCache + redemption tables) — see
        // RedemptionStore.swift, which owns both the migration content and
        // every real read/write against them, matching this file's own
        // "each feature owns its migration step" convention.
        RedemptionMigrations.register(&migrator)

        return migrator
    }
}
