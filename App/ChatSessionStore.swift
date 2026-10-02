import Foundation
import GRDB
import VisionCore

struct ChatSessionSummary: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "chatSession"
    var id: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
}

struct ChatSessionMessage: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "chatMessage"
    var id: String
    var sessionId: String
    var role: String
    var content: String
    var category: String?
    var providerName: String?
    var createdAt: Date
}

/// Real, persisted multi-session conversations — GRDB port of
/// ChatSessionDbHelper.kt, the data layer behind Ask VISION. A session
/// row is only ever created on an actual first exchange, never for an
/// empty "New chat" nobody used.
///
/// Android's `offline_url`/`live_source_url`/`memory_candidate` columns
/// are deliberately NOT ported — this app has no hidden-WKWebView
/// content-fetch or Memory feature yet to populate them (see README's
/// disclosed scope trim); there's nothing real for those fields to hold.
final class ChatSessionStore: ObservableObject {
    private let dbQueue: DatabaseQueue
    init(dbQueue: DatabaseQueue = AppDatabase.shared) { self.dbQueue = dbQueue }

    @discardableResult
    func createSession(title: String) throws -> ChatSessionSummary {
        let now = Date()
        let session = ChatSessionSummary(id: UUID().uuidString, title: title, createdAt: now, updatedAt: now)
        try dbQueue.write { db in try session.insert(db) }
        return session
    }

    func touchSession(_ id: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE chatSession SET updatedAt = ? WHERE id = ?", arguments: [Date(), id])
        }
    }

    func deleteSession(_ id: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM chatMessage WHERE sessionId = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM chatSession WHERE id = ?", arguments: [id])
        }
    }

    /// Metadata only — never fetches every session's messages just to render the list.
    func listSessions() throws -> [ChatSessionSummary] {
        try dbQueue.read { db in
            try ChatSessionSummary.order(Column("updatedAt").desc).fetchAll(db)
        }
    }

    @discardableResult
    func addMessage(sessionId: String, role: String, content: String, category: String?, providerName: String?) throws -> ChatSessionMessage {
        let message = ChatSessionMessage(id: UUID().uuidString, sessionId: sessionId, role: role, content: content, category: category, providerName: providerName, createdAt: Date())
        try dbQueue.write { db in try message.insert(db) }
        return message
    }

    func messagesForSession(_ sessionId: String) throws -> [ChatSessionMessage] {
        try dbQueue.read { db in
            try ChatSessionMessage.filter(Column("sessionId") == sessionId).order(Column("createdAt").asc).fetchAll(db)
        }
    }
}
