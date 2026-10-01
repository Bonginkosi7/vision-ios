import Foundation
import GRDB
import VisionCore

/// Real hierarchical topic/subtopic extracted from an uploaded document —
/// direct port of Topic (TopicDbHelper.kt).
struct Topic: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "topic"
    var id: String
    var documentId: String
    var parentTopicId: String?
    var level: Int
    var name: String
    var summary: String?
    var ordinal: Int
}

/// Real local storage for a document's AI-identified topic outline — GRDB
/// port of TopicDbHelper.kt. Nothing here is invented beyond what one real
/// AI call (TopicExtractor.extract) actually returned.
final class TopicStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    /// Replaces every topic for this document — a fresh extraction never
    /// leaves stale topics behind, matching TopicDbHelper.kt exactly.
    @discardableResult
    func replaceForDocument(documentId: String, topics: [RawTopic]) throws -> [Topic] {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM topic WHERE documentId = ?", arguments: [documentId])
            var result: [Topic] = []
            for (topicIndex, raw) in topics.enumerated() {
                let topicRow = Topic(
                    id: UUID().uuidString, documentId: documentId, parentTopicId: nil,
                    level: 1, name: raw.name, summary: raw.summary.isEmpty ? nil : raw.summary, ordinal: topicIndex
                )
                try topicRow.insert(db)
                result.append(topicRow)
                for (subIndex, sub) in raw.subtopics.enumerated() {
                    let subRow = Topic(
                        id: UUID().uuidString, documentId: documentId, parentTopicId: topicRow.id,
                        level: 2, name: sub.name, summary: sub.summary.isEmpty ? nil : sub.summary, ordinal: subIndex
                    )
                    try subRow.insert(db)
                    result.append(subRow)
                }
            }
            return result
        }
    }

    func listForDocument(_ documentId: String) throws -> [Topic] {
        try dbQueue.read { db in
            try Topic
                .filter(Column("documentId") == documentId)
                .order(Column("level").asc, Column("ordinal").asc)
                .fetchAll(db)
        }
    }
}
