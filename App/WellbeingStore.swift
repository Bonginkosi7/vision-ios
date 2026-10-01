import Foundation
import GRDB

/// Real local wellbeing tracking — GRDB port of WellbeingDbHelper.kt.
/// Everything here is derived from real events (breaks actually taken,
/// pages actually visited) — never a fabricated "distraction" or
/// "research" score, since this app has no real basis to classify
/// browsing content that way.
final class WellbeingStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    func recordBreak() throws {
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO wellbeingEvent (id, type, createdAt) VALUES (?, 'break', ?)", arguments: [UUID().uuidString, Date()])
        }
    }

    func breaksToday() throws -> Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wellbeingEvent WHERE type = 'break' AND createdAt >= ?", arguments: [startOfToday]) ?? 0
        }
    }

    /// A minimal, real record of distinct hostnames visited — just enough
    /// to answer "how many different sites today" honestly. Not a
    /// browsing-history feature (that's HistoryStore); no titles, no URLs
    /// beyond the host.
    func recordSiteVisit(hostname: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO siteVisit (hostname, visitedAt) VALUES (?, ?)", arguments: [hostname, Date()])
        }
    }

    func distinctSitesToday() throws -> Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(DISTINCT hostname) FROM siteVisit WHERE visitedAt >= ?", arguments: [startOfToday]) ?? 0
        }
    }
}
