import XCTest
@testable import VisionCore

/// Direct port of real StudyReviewDbHelper.kt cases (vision-android).
final class StudyReviewLogicTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    func test_neverReviewedItemIsDueWithZeroReviewCountAndIntervalDays() {
        let entries = StudyReviewLogic.dueEntries(itemIds: ["a"], rows: [:], now: now)
        XCTAssertEqual(entries, [StudyQueueEntry(itemId: "a", reviewCount: 0, intervalDays: 0)])
    }

    func test_overdueReviewedItemIsDue() {
        let row = StudyReviewRow(intervalTier: 0, reviewCount: 2, nextDueAt: now.addingTimeInterval(-10))
        let entries = StudyReviewLogic.dueEntries(itemIds: ["b"], rows: ["b": row], now: now)
        XCTAssertEqual(entries, [StudyQueueEntry(itemId: "b", reviewCount: 2, intervalDays: 1)])
    }

    func test_notYetDueItemIsExcluded() {
        let row = StudyReviewRow(intervalTier: 2, reviewCount: 3, nextDueAt: now.addingTimeInterval(1000))
        XCTAssertTrue(StudyReviewLogic.dueEntries(itemIds: ["c"], rows: ["c": row], now: now).isEmpty)
    }

    func test_mixedDueEntriesSortedByIntervalDaysWithNotDueExcluded() {
        let overdueRow = StudyReviewRow(intervalTier: 0, reviewCount: 2, nextDueAt: now.addingTimeInterval(-10))
        let notDueRow = StudyReviewRow(intervalTier: 2, reviewCount: 3, nextDueAt: now.addingTimeInterval(1000))
        let entries = StudyReviewLogic.dueEntries(itemIds: ["a", "b", "c"], rows: ["b": overdueRow, "c": notDueRow], now: now)
        XCTAssertEqual(entries.map { $0.itemId }, ["a", "b"], "never-reviewed (intervalDays 0) sorts before the overdue 1-day item")
    }

    func test_nextUpcomingDueAt() {
        let overdueRow = StudyReviewRow(intervalTier: 0, reviewCount: 2, nextDueAt: now.addingTimeInterval(-10))
        let notDueRow = StudyReviewRow(intervalTier: 2, reviewCount: 3, nextDueAt: now.addingTimeInterval(1000))
        XCTAssertEqual(StudyReviewLogic.nextUpcomingDueAt(itemIds: ["b", "c"], rows: ["b": overdueRow, "c": notDueRow], now: now), notDueRow.nextDueAt)
        XCTAssertNil(StudyReviewLogic.nextUpcomingDueAt(itemIds: ["a"], rows: [:], now: now))
    }

    func test_firstConfidentReviewStartsAtTierZero() {
        let update = StudyReviewLogic.review(existing: nil, confident: true, now: now)
        XCTAssertEqual(update.intervalTier, 0)
        XCTAssertEqual(update.reviewCount, 1)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(1 * 24 * 60 * 60))
    }

    func test_secondConfidentReviewAdvancesATier() {
        let update = StudyReviewLogic.review(existing: StudyReviewRow(intervalTier: 0, reviewCount: 1, nextDueAt: now), confident: true, now: now)
        XCTAssertEqual(update.intervalTier, 1)
        XCTAssertEqual(update.reviewCount, 2)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(3 * 24 * 60 * 60))
    }

    func test_notConfidentReviewResetsToTierZero() {
        let update = StudyReviewLogic.review(existing: StudyReviewRow(intervalTier: 3, reviewCount: 5, nextDueAt: now), confident: false, now: now)
        XCTAssertEqual(update.intervalTier, 0)
        XCTAssertEqual(update.reviewCount, 6)
    }

    func test_confidentReviewAtMaxTierStaysCapped() {
        let update = StudyReviewLogic.review(existing: StudyReviewRow(intervalTier: 4, reviewCount: 10, nextDueAt: now), confident: true, now: now)
        XCTAssertEqual(update.intervalTier, 4)
    }

    func test_currentStreak() {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        XCTAssertEqual(StudyReviewLogic.currentStreak(eventDates: [], now: now, calendar: calendar), 0)
        XCTAssertEqual(StudyReviewLogic.currentStreak(eventDates: [today], now: now, calendar: calendar), 1)
        XCTAssertEqual(StudyReviewLogic.currentStreak(eventDates: [yesterday, today], now: now, calendar: calendar), 2)
        XCTAssertEqual(StudyReviewLogic.currentStreak(eventDates: [yesterday], now: now, calendar: calendar), 1, "a streak counts through today even if today's review hasn't happened yet, as long as yesterday's did")
        XCTAssertEqual(StudyReviewLogic.currentStreak(eventDates: [yesterday, twoDaysAgo], now: now, calendar: calendar), 2)
        XCTAssertEqual(StudyReviewLogic.currentStreak(eventDates: [today, threeDaysAgo], now: now, calendar: calendar), 1, "a gap breaks the streak")
    }
}
