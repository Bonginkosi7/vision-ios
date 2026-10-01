import Foundation
import GRDB

/// One real visited page — direct port of HistoryEntry (HistoryDbHelper.kt).
struct HistoryEntry: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "historyEntry"

    var id: String
    var url: String
    var title: String
    var visitedAt: Date
}

/// Real local browsing history — GRDB port of HistoryDbHelper.kt. Genuinely
/// distinct from Bookmarks (explicit user saves): this is a log of every
/// page actually visited, written once per real navigation on a
/// non-private tab (private tabs never call `record`, matching Android's
/// PrivateBrowsingActivity never touching HistoryDbHelper).
final class HistoryStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    func record(url: String, title: String) throws {
        let entry = HistoryEntry(
            id: UUID().uuidString,
            url: url,
            title: title.isEmpty ? url : title,
            visitedAt: Date()
        )
        try dbQueue.write { db in
            try entry.insert(db)
        }
    }

    func list(limit: Int = 500) throws -> [HistoryEntry] {
        try dbQueue.read { db in
            try HistoryEntry.order(Column("visitedAt").desc).limit(limit).fetchAll(db)
        }
    }

    func search(_ query: String, limit: Int = 200) throws -> [HistoryEntry] {
        let like = "%\(query)%"
        return try dbQueue.read { db in
            try HistoryEntry
                .filter(Column("url").like(like) || Column("title").like(like))
                .order(Column("visitedAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func deleteEntry(id: String) throws {
        _ = try dbQueue.write { db in
            try HistoryEntry.deleteOne(db, key: id)
        }
    }

    func clear() throws {
        _ = try dbQueue.write { db in
            try HistoryEntry.deleteAll(db)
        }
    }
}
