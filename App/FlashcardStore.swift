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
/// FlashcardDbHelper.kt. `reviewEventsForTopic` (Performance's real
/// per-topic mastery aggregation) is deliberately not ported yet: its
/// return type depends on MasteryEvent/the mastery engine, neither of
/// which exists on iOS until Performance's own phase — the
/// `flashcardReviewEvent` table itself is still written for real by
/// `markReviewed` below, so that data exists and is ready once Performance
/// lands and genuinely needs to read it.
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
}
