import Foundation
import GRDB
import VisionCore

/// Real AI-generated flashcard with its real spaced-repetition review
/// state — direct port of Flashcard (FlashcardDbHelper.kt).
struct Flashcard: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "flashcard"
    var id: String
    var documentId: String
    var front: String
    var back: String
    var createdAt: Date
    // -1 means never reviewed — distinct from a real tier-0 row, same
    // reasoning as Flashcard.kt's own intervalTier.
    var intervalTier: Int
    var reviewCount: Int
    var nextDueAt: Date?
    var topicId: String?

    var intervalDays: Int { FlashcardScheduling.intervalDays(forTier: intervalTier) }
}

struct NewFlashcard {
    let front: String
    let back: String
    let topicId: String?
}

/// Real local storage for AI-generated flashcards — GRDB port of
/// FlashcardDbHelper.kt. `reviewEventsForTopic` closes the trim this
/// file's doc comment used to describe: Performance (Phase 12) now
/// exists and is the real consumer of the `flashcardReviewEvent` rows
/// `markReviewed` has been writing since Phase 9.
final class FlashcardStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    @discardableResult
    func createMany(documentId: String, cards: [NewFlashcard]) throws -> [Flashcard] {
        let now = Date()
        let created = cards.map { c in
            Flashcard(
                id: UUID().uuidString, documentId: documentId, front: c.front, back: c.back,
                createdAt: now, intervalTier: -1, reviewCount: 0, nextDueAt: nil, topicId: c.topicId
            )
        }
        try dbQueue.write { db in
            for card in created { try card.insert(db) }
        }
        return created
    }

    func listForDocument(_ documentId: String) throws -> [Flashcard] {
        try dbQueue.read { db in
            try Flashcard
                .filter(Column("documentId") == documentId)
                .order(Column("createdAt").asc)
                .fetchAll(db)
        }
    }

    /// Due now or never reviewed — never-reviewed cards first, then
    /// shortest-interval (least-entrenched) first, matching
    /// FlashcardDbHelper.kt's dueForDocument sort exactly.
    func dueForDocument(_ documentId: String) throws -> [Flashcard] {
        let now = Date()
        return try listForDocument(documentId)
            .filter { $0.nextDueAt == nil || $0.nextDueAt! <= now }
            .sorted { $0.intervalDays < $1.intervalDays }
    }

    func markReviewed(_ flashcardId: String, confident: Bool) throws {
        guard let existing = try get(flashcardId) else { return }
        let nextTier = FlashcardScheduling.nextTier(priorTier: existing.intervalTier, confident: confident)
        let now = Date()
        let nextDueAt = FlashcardScheduling.nextDueAt(now: now, tier: nextTier)
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE flashcard SET intervalTier = ?, reviewCount = ?, nextDueAt = ? WHERE id = ?",
                arguments: [nextTier, existing.reviewCount + 1, nextDueAt, flashcardId]
            )
            try db.execute(
                sql: "INSERT INTO flashcardReviewEvent (id, flashcardId, confident, createdAt) VALUES (?, ?, ?, ?)",
                arguments: [UUID().uuidString, flashcardId, confident, now]
            )
        }
    }

    func get(_ id: String) throws -> Flashcard? {
        try dbQueue.read { db in try Flashcard.fetchOne(db, key: id) }
    }

    /// Every real review event for flashcards tagged to this topic, most
    /// recent first — feeds `MasteryEngine` via `PerformanceCalculator`.
    /// Direct port of FlashcardDbHelper.kt's reviewEventsForTopic.
    func reviewEventsForTopic(_ topicId: String) throws -> [MasteryEvent] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT e.confident, e.createdAt
                FROM flashcardReviewEvent e
                JOIN flashcard c ON c.id = e.flashcardId
                WHERE c.topicId = ?
                ORDER BY e.createdAt DESC
                """, arguments: [topicId])
            return rows.map { row in MasteryEvent(correct: row["confident"], createdAt: row["createdAt"]) }
        }
    }
}
