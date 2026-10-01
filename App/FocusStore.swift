import Foundation
import GRDB

/// Real blocked domain — direct port of focus_blocklist (FocusDbHelper.kt).
struct FocusBlockedDomain: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "focusBlockedDomain"
    var domain: String
    var addedAt: Date
    var id: String { domain }
}

/// Real focus session record — direct port of FocusSession (FocusDbHelper.kt).
struct FocusSessionRecord: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "focusSession"
    var id: String
    var startedAt: Date
    var endedAt: Date?
    var plannedMinutes: Int
    var blockedAttempts: Int
}

/// Real local storage for Focus Mode — GRDB port of FocusDbHelper.kt. The
/// block list is only ever what the user explicitly adds, same as
/// Android/desktop — never a built-in "distracting sites" list this app
/// has no honest basis to curate itself.
final class FocusStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    /// "https://www.youtube.com/watch?v=..." -> "youtube.com". Accepts a bare domain too.
    private func normalizeDomain(_ input: String) -> String {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let schemeRange = value.range(of: "^[a-z]+://", options: .regularExpression) {
            value.removeSubrange(schemeRange)
        }
        if let slashIndex = value.firstIndex(of: "/") {
            value = String(value[value.startIndex..<slashIndex])
        }
        if value.hasPrefix("www.") {
            value = String(value.dropFirst(4))
        }
        return value
    }

    func listBlockedDomains() throws -> [String] {
        try dbQueue.read { db in
            try FocusBlockedDomain.order(Column("addedAt").asc).fetchAll(db).map { $0.domain }
        }
    }

    func addBlockedDomain(_ input: String) throws {
        let domain = normalizeDomain(input)
        guard !domain.isEmpty else { return }
        try dbQueue.write { db in
            // CONFLICT_IGNORE on the Android side — same real "adding an
            // already-blocked domain is a no-op, not an error" behavior.
            try db.execute(sql: "INSERT OR IGNORE INTO focusBlockedDomain (domain, addedAt) VALUES (?, ?)", arguments: [domain, Date()])
        }
    }

    func removeBlockedDomain(_ domain: String) throws {
        _ = try dbQueue.write { db in
            try FocusBlockedDomain.deleteOne(db, key: domain)
        }
    }

    func startSession(id: String, startedAt: Date, plannedMinutes: Int) throws {
        let record = FocusSessionRecord(id: id, startedAt: startedAt, endedAt: nil, plannedMinutes: plannedMinutes, blockedAttempts: 0)
        try dbQueue.write { db in try record.insert(db) }
    }

    func endSession(id: String, blockedAttempts: Int) throws {
        try dbQueue.write { db in
            guard var record = try FocusSessionRecord.fetchOne(db, key: id) else { return }
            record.endedAt = Date()
            record.blockedAttempts = blockedAttempts
            try record.update(db)
        }
    }

    /// A session row left with no endedAt from a previous run the process
    /// died mid-session can't actually still be active — there's no
    /// in-memory timer left to end it. Closed as data hygiene at startup
    /// rather than left permanently dangling, same as Android's
    /// closeDanglingSessions().
    func closeDanglingSessions() throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE focusSession SET endedAt = startedAt WHERE endedAt IS NULL")
        }
    }

    func sessionsCompletedToday() throws -> Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM focusSession WHERE endedAt IS NOT NULL AND startedAt >= ?",
                arguments: [startOfToday]
            ) ?? 0
        }
    }
}
