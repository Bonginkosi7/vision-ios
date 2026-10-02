import Foundation

/// A real, persisted review-schedule row for one offline-saved item —
/// direct port of the row shape `StudyReviewDbHelper.kt` stores.
public struct StudyReviewRow: Equatable {
    public let intervalTier: Int
    public let reviewCount: Int
    public let nextDueAt: Date

    public init(intervalTier: Int, reviewCount: Int, nextDueAt: Date) {
        self.intervalTier = intervalTier
        self.reviewCount = reviewCount
        self.nextDueAt = nextDueAt
    }
}

public struct StudyQueueEntry: Equatable {
    public let itemId: String
    public let reviewCount: Int
    public let intervalDays: Int

    public init(itemId: String, reviewCount: Int, intervalDays: Int) {
        self.itemId = itemId
        self.reviewCount = reviewCount
        self.intervalDays = intervalDays
    }
}

public struct StudyReviewUpdate: Equatable {
    public let intervalTier: Int
    public let reviewCount: Int
    public let nextDueAt: Date

    public init(intervalTier: Int, reviewCount: Int, nextDueAt: Date) {
        self.intervalTier = intervalTier
        self.reviewCount = reviewCount
        self.nextDueAt = nextDueAt
    }
}

/// Spaced review scheduling for the user's own offline-saved "education"
/// category pages — direct port of `StudyReviewDbHelper.kt`'s real
/// calculations, itself the Android counterpart of desktop's
/// `StudyStore.ts`. Never fabricated flashcards or quiz content: there's
/// no honest basis to generate facts/questions about an arbitrary saved
/// page, so this only ever resurfaces the user's own material on a
/// schedule — the "studying" is theirs. A simple Leitner-style schedule,
/// not full SM-2, same real tradeoff desktop/Android already made.
///
/// `now`/`calendar` are injectable (default to the real clock/calendar)
/// so every case here is testable without waiting on the actual date —
/// same pattern `MasteryEngine` already established in this codebase.
public enum StudyReviewLogic {
    public static let intervalTiersDays = [1, 3, 7, 14, 30]

    /// Items that are either due now or have never been reviewed —
    /// never-reviewed first (interval 0), then shortest-interval first.
    public static func dueEntries(itemIds: [String], rows: [String: StudyReviewRow], now: Date = Date()) -> [StudyQueueEntry] {
        var entries: [StudyQueueEntry] = []
        for id in itemIds {
            guard let row = rows[id] else {
                entries.append(StudyQueueEntry(itemId: id, reviewCount: 0, intervalDays: 0))
                continue
            }
            if row.nextDueAt <= now {
                let intervalDays = intervalTiersDays.indices.contains(row.intervalTier) ? intervalTiersDays[row.intervalTier] : 1
                entries.append(StudyQueueEntry(itemId: id, reviewCount: row.reviewCount, intervalDays: intervalDays))
            }
        }
        return entries.sorted { $0.intervalDays < $1.intervalDays }
    }

    /// Soonest upcoming due time among items that are NOT currently due — `nil` if nothing is scheduled at all.
    public static func nextUpcomingDueAt(itemIds: [String], rows: [String: StudyReviewRow], now: Date = Date()) -> Date? {
        var soonest: Date?
        for id in itemIds {
            guard let row = rows[id], row.nextDueAt > now else { continue }
            if soonest == nil || row.nextDueAt < soonest! { soonest = row.nextDueAt }
        }
        return soonest
    }

    /// The real schedule update `markReviewed` computes — confident advances one tier (capped at the last), not-confident resets to tier 0.
    public static func review(existing: StudyReviewRow?, confident: Bool, now: Date = Date()) -> StudyReviewUpdate {
        let nextTier = confident ? min((existing?.intervalTier ?? -1) + 1, intervalTiersDays.count - 1) : 0
        let intervalDays = intervalTiersDays[nextTier]
        let nextDueAt = now.addingTimeInterval(TimeInterval(intervalDays) * 24 * 60 * 60)
        let reviewCount = (existing?.reviewCount ?? 0) + 1
        return StudyReviewUpdate(intervalTier: nextTier, reviewCount: reviewCount, nextDueAt: nextDueAt)
    }

    /// Consecutive calendar days (ending today or yesterday) with at least one real review — resets to 0 the moment a day is skipped.
    public static func currentStreak(eventDates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(eventDates.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
