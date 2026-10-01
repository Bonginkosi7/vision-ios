import Foundation
import GRDB
import VisionCore

/// Real uploaded study document — direct port of StudyDocument.kt's core
/// fields. Deliberately narrower than Android's own final schema: it
/// doesn't carry Android's later-added taxonomy (level/grade/category/
/// subject/resourceType/year/language) or offlineReadyAt columns, since
/// those belong to Android's separate, bigger "Study Material hub"
/// feature (StudyMaterialActivity.kt) this phase does not port — see
/// README. Those columns land in their own migration if/when that hub
/// gets built, not speculatively now.
struct StudyDocument: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "studyDocument"
    var id: String
    var title: String
    var originalFilename: String
    var fileType: StudyFileType
    var contentPath: String
    var sizeBytes: Int64
    var status: StudyDocumentStatus
    var processingError: String?
    var extractedText: String?
    var createdAt: Date
}

/// Real local storage for uploaded study documents — GRDB port of the
/// slice of StudyDocumentDbHelper.kt that MaterialsActivity.kt/
/// MaterialsAdapter.kt ("My Materials") actually uses.
final class StudyDocumentStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    @discardableResult
    func insert(_ document: StudyDocument) throws -> StudyDocument {
        try dbQueue.write { db in try document.insert(db) }
        return document
    }

    func updateProcessing(id: String, status: StudyDocumentStatus, processingError: String?, extractedText: String?) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE studyDocument SET status = ?, processingError = ?, extractedText = ? WHERE id = ?",
                arguments: [status.rawValue, processingError, extractedText, id]
            )
        }
    }

    func get(id: String) throws -> StudyDocument? {
        try dbQueue.read { db in try StudyDocument.fetchOne(db, key: id) }
    }

    func list() throws -> [StudyDocument] {
        try dbQueue.read { db in
            try StudyDocument.order(Column("createdAt").desc).fetchAll(db)
        }
    }

    func remove(id: String) throws {
        _ = try dbQueue.write { db in try StudyDocument.deleteOne(db, key: id) }
    }
}
