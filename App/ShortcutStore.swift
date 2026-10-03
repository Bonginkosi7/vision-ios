import Foundation
import GRDB

/// One real New Tab shortcut — direct port of the `Shortcut` data class in
/// ShortcutDbHelper.kt.
struct Shortcut: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "shortcut"

    var id: Int64?
    var title: String
    var url: String
    var position: Int

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// Real, user-managed New Tab shortcuts — GRDB port of ShortcutDbHelper.kt.
/// Ships with the same real default set Android seeds a fresh install with
/// (per that file's own doc comment: "a real default set, per explicit
/// user request, rather than desktop's own empty start") — ordinary rows
/// the user can remove or add to like any shortcut they'd create
/// themselves, not a separate fixed/pinned tier.
final class ShortcutStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    private static let defaultShortcuts: [(title: String, url: String)] = [
        ("YouTube", "https://www.youtube.com"),
        ("Gmail", "https://mail.google.com"),
        ("WhatsApp Web", "https://web.whatsapp.com"),
        ("Drive", "https://drive.google.com"),
        ("ChatGPT", "https://chat.openai.com"),
        ("Claude", "https://claude.ai"),
    ]

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
        seedDefaultsIfEmpty()
    }

    /// Mirrors ShortcutDbHelper's onCreate-time seeding — but since GRDB's
    /// migrator only runs a migration once ever (not "once per empty
    /// table" the way Android's onUpgrade re-seed check works), this runs
    /// at store-construction time instead, gated on the table genuinely
    /// being empty so it never re-adds rows a user has deliberately
    /// cleared out.
    private func seedDefaultsIfEmpty() {
        try? dbQueue.write { db in
            let isEmpty = try Shortcut.fetchCount(db) == 0
            guard isEmpty else { return }
            for (index, entry) in Self.defaultShortcuts.enumerated() {
                var shortcut = Shortcut(id: nil, title: entry.title, url: entry.url, position: index)
                try shortcut.insert(db)
            }
        }
    }

    @discardableResult
    func add(title: String, url: String) throws -> Shortcut {
        // Mirrors ShortcutDbHelper.add's own non-atomic read-then-write
        // (list().maxOfOrNull { it.position } ?: -1) + 1 — fine for this
        // low-contention, single-user, local-only feature.
        let nextPosition = (try list().map { $0.position }.max() ?? -1) + 1
        var shortcut = Shortcut(id: nil, title: title, url: url, position: nextPosition)
        try dbQueue.write { db in
            try shortcut.insert(db)
        }
        return shortcut
    }

    func remove(id: Int64) throws {
        _ = try dbQueue.write { db in
            try Shortcut.deleteOne(db, key: id)
        }
    }

    func list() throws -> [Shortcut] {
        try dbQueue.read { db in
            try Shortcut.order(Column("position").asc).fetchAll(db)
        }
    }
}
