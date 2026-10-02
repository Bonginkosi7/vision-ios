import Foundation
import GRDB
import VisionCore

/// Real uploaded study document — direct port of StudyDocument.kt's
/// fields, including the real taxonomy (level/grade/category/subject/
/// resourceType/year/language) and offlineReadyAt columns added in
/// v11_phase18 for the Study Material hub.
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
    var level: StudyLevel? = nil
    var grade: String? = nil
    var category: String? = nil
    var subject: String? = nil
    var resourceType: String? = nil
    var year: Int? = nil
    var language: String? = nil
    var offlineReadyAt: Date? = nil

    var taxonomy: StudyDocumentTaxonomy {
        StudyDocumentTaxonomy(level: level, grade: grade, category: category, subject: subject, resourceType: resourceType, year: year, language: language)
    }
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

    /// Real user-assigned taxonomy on their own uploaded document — never inferred or fabricated.
    func setTaxonomy(id: String, taxonomy: StudyDocumentTaxonomy) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE studyDocument SET level = ?, grade = ?, category = ?, subject = ?, resourceType = ?, year = ?, language = ? WHERE id = ?",
                arguments: [taxonomy.level?.rawValue, taxonomy.grade, taxonomy.category, taxonomy.subject, taxonomy.resourceType, taxonomy.year, taxonomy.language, id]
            )
        }
    }

    func markOfflineReady(id: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE studyDocument SET offlineReadyAt = ? WHERE id = ?", arguments: [Date(), id])
        }
    }
}
