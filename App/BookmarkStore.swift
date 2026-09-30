import Foundation
import GRDB

/// One real saved bookmark — direct port of the `Bookmark` data class in
/// BookmarkDbHelper.kt.
struct Bookmark: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "bookmark"

    var id: Int64?
    var title: String
    var url: String
    var createdAt: Date

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// Real local SQLite storage for bookmarks — GRDB port of
/// BookmarkDbHelper.kt, same shape (add/remove/list/isBookmarked).
final class BookmarkStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    @discardableResult
    func add(title: String, url: String) throws -> Bookmark {
        var bookmark = Bookmark(id: nil, title: title, url: url, createdAt: Date())
        try dbQueue.write { db in
            try bookmark.insert(db)
        }
        return bookmark
    }

    func remove(id: Int64) throws {
        _ = try dbQueue.write { db in
            try Bookmark.deleteOne(db, key: id)
        }
    }

    func isBookmarked(url: String) throws -> Bookmark? {
        try dbQueue.read { db in
            try Bookmark.filter(Column("url") == url).fetchOne(db)
        }
    }

    func list() throws -> [Bookmark] {
        try dbQueue.read { db in
            try Bookmark.order(Column("createdAt").desc).fetchAll(db)
        }
    }
}
