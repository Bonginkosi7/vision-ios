import Foundation
import GRDB

/// Mirrors DownloadState (Download.kt) — no Android-specific states beyond
/// what a real WKDownload can report.
enum DownloadState: String, Codable {
    case progressing = "PROGRESSING"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
    case failed = "FAILED"
}

/// One real downloaded file — port of DownloadRecord (DownloadDbHelper.kt),
/// minus `systemDownloadId`: iOS has no separate system download-manager
/// service to interoperate with the way Android's DownloadManager is — a
/// WKDownload already *is* the real download, so there is nothing else to
/// track a reference to.
struct DownloadRecord: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "downloadRecord"

    var id: String
    var url: String
    var filename: String
    var mimeType: String?
    var state: DownloadState
    var receivedBytes: Int64
    var totalBytes: Int64
    var startedAt: Date
    var completedAt: Date?
}

/// Real local record of files downloaded through this browser — GRDB port
/// of DownloadDbHelper.kt. The actual transfer is done by a real
/// `WKDownload` (see WebViewRepresentable's Coordinator); this store just
/// tracks what was downloaded and its real on-disk state.
final class DownloadStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    @discardableResult
    func create(url: String, filename: String, mimeType: String?, totalBytes: Int64) throws -> DownloadRecord {
        let record = DownloadRecord(
            id: UUID().uuidString,
            url: url,
            filename: filename,
            mimeType: mimeType,
            state: .progressing,
            receivedBytes: 0,
            totalBytes: totalBytes,
            startedAt: Date(),
            completedAt: nil
        )
        try dbQueue.write { db in try record.insert(db) }
        return record
    }

    func updateProgress(id: String, receivedBytes: Int64, totalBytes: Int64? = nil, state: DownloadState) throws {
        try dbQueue.write { db in
            guard var record = try DownloadRecord.fetchOne(db, key: id) else { return }
            record.receivedBytes = receivedBytes
            if let totalBytes, totalBytes > 0 { record.totalBytes = totalBytes }
            record.state = state
            if state == .completed || state == .failed || state == .cancelled {
                record.completedAt = Date()
            }
            try record.update(db)
        }
    }

    func list() throws -> [DownloadRecord] {
        try dbQueue.read { db in
            try DownloadRecord.order(Column("startedAt").desc).fetchAll(db)
        }
    }

    func remove(id: String) throws {
        _ = try dbQueue.write { db in
            try DownloadRecord.deleteOne(db, key: id)
        }
    }
}
