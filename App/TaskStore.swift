import Foundation
import GRDB

/// Real personal task — direct port of ProductivityTask (TaskDbHelper.kt).
struct ProductivityTask: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "task"
    var id: String
    var title: String
    var createdAt: Date
    var completedAt: Date?
}

/// A minimal real personal task list — GRDB port of TaskDbHelper.kt. Every
/// task is real and user-authored; completion is one-way (see
/// `complete`'s real "was this actually still open" check) so a task
/// can't be un-checked and re-checked to farm reward points once Phase 7
/// wires that up.
final class TaskStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    @discardableResult
    func add(title: String) throws -> ProductivityTask {
        let task = ProductivityTask(id: UUID().uuidString, title: title, createdAt: Date(), completedAt: nil)
        try dbQueue.write { db in try task.insert(db) }
        return task
    }

    /// Returns the task if it was genuinely completed just now (was still
    /// open), or nil if it was already done — the caller uses this to
    /// award points exactly once per real completion, once Phase 7 wires
    /// reward eligibility up.
    @discardableResult
    func complete(id: String) throws -> ProductivityTask? {
        try dbQueue.write { db in
            guard var task = try ProductivityTask.fetchOne(db, key: id), task.completedAt == nil else { return nil }
            task.completedAt = Date()
            try task.update(db)
            return task
        }
    }

    func remove(id: String) throws {
        _ = try dbQueue.write { db in
            try ProductivityTask.deleteOne(db, key: id)
        }
    }

    /// Open tasks first (newest first), then completed tasks.
    func list() throws -> [ProductivityTask] {
        try dbQueue.read { db in
            try ProductivityTask
                .order(sql: "(completedAt IS NOT NULL) ASC, createdAt DESC")
                .fetchAll(db)
        }
    }
}
