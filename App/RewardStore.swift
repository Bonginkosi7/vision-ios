import Foundation
import GRDB
import VisionCore

/// Real reward event — direct port of RewardEvent (RewardDbHelper.kt).
public struct RewardEvent: Codable, Identifiable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "rewardEvent"
    public var id: String
    public var type: RewardEventType
    public var category: RewardCategory
    public var points: Int
    public var note: String
    public var dedupeKey: String?
    public var createdAt: Date
}

/// Real local points ledger — GRDB port of RewardDbHelper.kt. Every row is
/// one real, honestly-earned event.
///
/// `availableBalance()` now subtracts real redemption spend (`total() -
/// activeSpend()`), matching Android's own real formula exactly, now that
/// Redeem (RedemptionStore.swift) is ported. A direct SQL query against
/// the `redemption` table here, rather than a `RedemptionStore` instance
/// dependency, since `RedemptionStore.redeem()` itself already calls back
/// into this store's own `availableBalance()` to check eligibility — a
/// real circular dependency either side would otherwise introduce for no
/// benefit, when both stores already share the same `AppDatabase.shared`
/// queue.
final class RewardStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    func startOfToday() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// Monday 00:00 of the current real week, matching the desktop app's
    /// own ISO-style week start (and RewardDbHelper.kt's startOfWeek()).
    private func startOfWeek() -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) // 1 = Sunday
        let diffToMonday = weekday == 1 ? 6 : weekday - 2
        return calendar.date(byAdding: .day, value: -diffToMonday, to: today) ?? today
    }

    @discardableResult
    func award(type: RewardEventType, note: String, dedupeKey: String? = nil) throws -> RewardEvent {
        let event = RewardEvent(
            id: UUID().uuidString, type: type, category: type.rule.category,
            points: type.rule.points, note: note, dedupeKey: dedupeKey, createdAt: Date()
        )
        try dbQueue.write { db in try event.insert(db) }
        return event
    }

    func total() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(points), 0) FROM rewardEvent") ?? 0
        }
    }

    func availableBalance() throws -> Int {
        let activeSpend = try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(pointsCost), 0) FROM redemption WHERE status != 'FAILED'") ?? 0
        }
        return try total() - activeSpend
    }

    func totalThisWeek() throws -> Int {
        let start = startOfWeek()
        return try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(points), 0) FROM rewardEvent WHERE createdAt >= ?", arguments: [start]) ?? 0
        }
    }

    func pointsThisWeekByCategory() throws -> [RewardCategory: Int] {
        let start = startOfWeek()
        return try categoryTotals(sql: "SELECT category, COALESCE(SUM(points), 0) AS total FROM rewardEvent WHERE createdAt >= ? GROUP BY category", arguments: [start])
    }

    func recent(limit: Int = 20) throws -> [RewardEvent] {
        try dbQueue.read { db in
            try RewardEvent
                .order(Column("createdAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func hasEventTypeToday(_ type: RewardEventType) throws -> Bool {
        let start = startOfToday()
        return try dbQueue.read { db in
            try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM rewardEvent WHERE type = ? AND createdAt >= ?)", arguments: [type.rawValue, start]) ?? false
        }
    }

    func hasAwardForKey(_ key: String) throws -> Bool {
        try dbQueue.read { db in
            try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM rewardEvent WHERE dedupeKey = ?)", arguments: [key]) ?? false
        }
    }

    func countEventsSince(_ type: RewardEventType, since: Date) throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM rewardEvent WHERE type = ? AND createdAt >= ?", arguments: [type.rawValue, since]) ?? 0
        }
    }

    func countEventsThisWeek(_ type: RewardEventType) throws -> Int {
        try countEventsSince(type, since: startOfWeek())
    }

    /// Number of distinct calendar days this real week (Monday-start) with
    /// at least one reward event — the weekly-consistency check's own gate.
    func distinctActiveDaysThisWeek() throws -> Int {
        let start = startOfWeek()
        let dates = try dbQueue.read { db -> [Date] in
            try Date.fetchAll(db, sql: "SELECT createdAt FROM rewardEvent WHERE createdAt >= ?", arguments: [start])
        }
        let calendar = Calendar.current
        let days = Set(dates.map { calendar.ordinality(of: .day, in: .year, for: $0) ?? -1 })
        return days.count
    }

    func currentWeekLabel() -> String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: Date())
        let week = calendar.component(.weekOfYear, from: Date())
        return "\(year)-W\(week)"
    }

    private func categoryTotals(sql: String, arguments: StatementArguments) throws -> [RewardCategory: Int] {
        var result = Dictionary(uniqueKeysWithValues: RewardCategory.allCases.map { ($0, 0) })
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
            for row in rows {
                guard let categoryRaw: String = row["category"], let category = RewardCategory(rawValue: categoryRaw) else { continue }
                result[category] = row["total"]
            }
        }
        return result
    }
}
