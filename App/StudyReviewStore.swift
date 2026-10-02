import Foundation
import GRDB
import VisionCore

private struct StudyReviewRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "studyReview"
    var offlineItemId: String
    var intervalTier: Int
    var reviewCount: Int
    var nextDueAt: Date
}

private struct StudyReviewEventRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "studyReviewEvent"
    var id: String
    var offlineItemId: String
    var confident: Bool
    var createdAt: Date
}

/// Real local storage backing `VisionCore.StudyReviewLogic` — GRDB port
/// of `StudyReviewDbHelper.kt`'s two tables. All the actual scheduling
/// math (due/not-due, tier advancement, streak) lives in the pure,
/// tested `StudyReviewLogic`; this store only does real reads/writes.
final class StudyReviewStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    private func rows(for itemIds: [String]) throws -> [String: StudyReviewRow] {
        try dbQueue.read { db in
            let records = try StudyReviewRecord.filter(itemIds.contains(Column("offlineItemId"))).fetchAll(db)
            return Dictionary(uniqueKeysWithValues: records.map {
                ($0.offlineItemId, StudyReviewRow(intervalTier: $0.intervalTier, reviewCount: $0.reviewCount, nextDueAt: $0.nextDueAt))
            })
        }
    }

    func dueEntries(itemIds: [String]) throws -> [StudyQueueEntry] {
        StudyReviewLogic.dueEntries(itemIds: itemIds, rows: try rows(for: itemIds))
    }

    func nextUpcomingDueAt(itemIds: [String]) throws -> Date? {
        StudyReviewLogic.nextUpcomingDueAt(itemIds: itemIds, rows: try rows(for: itemIds))
    }

    func markReviewed(offlineItemId: String, confident: Bool) throws {
        try dbQueue.write { db in
            let existingRecord = try StudyReviewRecord.fetchOne(db, key: offlineItemId)
            let existing = existingRecord.map { StudyReviewRow(intervalTier: $0.intervalTier, reviewCount: $0.reviewCount, nextDueAt: $0.nextDueAt) }
            let update = StudyReviewLogic.review(existing: existing, confident: confident)

            try db.execute(
                sql: "INSERT OR REPLACE INTO studyReview (offlineItemId, intervalTier, reviewCount, nextDueAt) VALUES (?, ?, ?, ?)",
                arguments: [offlineItemId, update.intervalTier, update.reviewCount, update.nextDueAt]
            )

            try StudyReviewEventRecord(id: UUID().uuidString, offlineItemId: offlineItemId, confident: confident, createdAt: Date())
                .insert(db)
        }
    }

    func currentStreak() throws -> Int {
        try dbQueue.read { db in
            let dates = try Date.fetchAll(db, sql: "SELECT createdAt FROM studyReviewEvent")
            return StudyReviewLogic.currentStreak(eventDates: dates)
        }
    }
}
