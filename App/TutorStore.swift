import Foundation
import GRDB
import VisionCore

struct TutorSession: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tutorSession"
    var id: String
    var documentId: String?
    var title: String
    var createdAt: Date
    var updatedAt: Date
}

struct TutorMessage: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tutorMessage"
    var id: String
    var sessionId: String
    var role: String
    var content: String
    var groundedInDocument: Bool?
    var providerName: String?
    var createdAt: Date
}

/// Real local storage for AI Tutor conversations — GRDB port of
/// TutorDbHelper.kt. Drops citedChunkIds/lessonId/timestampSeconds
/// entirely, not as always-nil columns: this app has no document-
/// chunking/retrieval layer and no lessons feature, so there's nothing
/// real for those fields to hold (see TutorLogic.swift for how grounding
/// works here instead).
final class TutorStore: ObservableObject {
    private let dbQueue: DatabaseQueue
    init(dbQueue: DatabaseQueue = AppDatabase.shared) { self.dbQueue = dbQueue }

    @discardableResult
    func createSession(documentId: String?, title: String) throws -> TutorSession {
        let now = Date()
        let session = TutorSession(id: UUID().uuidString, documentId: documentId, title: title, createdAt: now, updatedAt: now)
        try dbQueue.write { db in try session.insert(db) }
        return session
    }

    func touchSession(_ id: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE tutorSession SET updatedAt = ? WHERE id = ?", arguments: [Date(), id])
        }
    }

    @discardableResult
    func addMessage(sessionId: String, role: String, content: String, groundedInDocument: Bool?, providerName: String?) throws -> TutorMessage {
        let message = TutorMessage(id: UUID().uuidString, sessionId: sessionId, role: role, content: content, groundedInDocument: groundedInDocument, providerName: providerName, createdAt: Date())
        try dbQueue.write { db in try message.insert(db) }
        return message
    }

    func messagesForSession(_ sessionId: String) throws -> [TutorMessage] {
        try dbQueue.read { db in
            try TutorMessage.filter(Column("sessionId") == sessionId).order(Column("createdAt").asc).fetchAll(db)
        }
    }
}
