import Foundation
import GRDB

/// One real saved-for-offline page — port of OfflineItem's core columns
/// (OfflineDbHelper.kt). Smart Cache's refresh-tracking columns
/// (etag/lastModified/contentHash/nextRefreshAt) and the recommendations
/// table are a disclosed scope trim for this phase — there's no background
/// refresh worker yet to use them (see README).
struct OfflineItem: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "offlineItem"

    var id: String
    var url: String
    var title: String
    var contentPath: String
    var sizeBytes: Int64
    var savedAt: Date
    var category: String
}

/// Real local storage for offline-saved pages — GRDB port of
/// OfflineDbHelper.kt's core add/remove/list surface. The actual page
/// snapshot is captured by `WKWebView.createWebArchiveData(completionHandler:)`
/// — Apple's own real, native page-archive mechanism, the direct iOS
/// counterpart of Android's `WebView.saveWebArchive()` — and written to a
/// real `.webarchive` file under Application Support/OfflineLibrary/; this
/// store only tracks the resulting file's metadata.
final class OfflineStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    @discardableResult
    func add(url: String, title: String, contentPath: String, sizeBytes: Int64, category: String = "general") throws -> OfflineItem {
        let item = OfflineItem(
            id: UUID().uuidString,
            url: url,
            title: title,
            contentPath: contentPath,
            sizeBytes: sizeBytes,
            savedAt: Date(),
            category: category
        )
        try dbQueue.write { db in try item.insert(db) }
        return item
    }

    func remove(id: String) throws {
        _ = try dbQueue.write { db in
            try OfflineItem.deleteOne(db, key: id)
        }
    }

    func findByUrl(_ url: String) throws -> OfflineItem? {
        try dbQueue.read { db in
            try OfflineItem.filter(Column("url") == url).fetchOne(db)
        }
    }

    func list() throws -> [OfflineItem] {
        try dbQueue.read { db in
            try OfflineItem.order(Column("savedAt").desc).fetchAll(db)
        }
    }

    func totalSizeBytes() throws -> Int64 {
        try dbQueue.read { db in
            try Int64.fetchOne(db, sql: "SELECT COALESCE(SUM(sizeBytes), 0) FROM offlineItem") ?? 0
        }
    }
}
