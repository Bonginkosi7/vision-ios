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

        return migrator
    }
}
