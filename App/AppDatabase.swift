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
            // narrower than Android's own final schema: no taxonomy
            // (level/grade/category/subject/resourceType/year/language)
            // or offlineReadyAt columns yet — those belong to Android's
            // separate, bigger "Study Material hub" this phase does not
            // port (see README's disclosed scope trim). They land in
            // their own migration if/when that hub gets built.
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

        return migrator
    }
}
