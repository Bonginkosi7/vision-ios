import XCTest
@testable import VisionCore

/// Direct port of FlashcardSchedulingTest.kt's real cases.
final class FlashcardSchedulingTests: XCTestCase {
    func test_aNeverReviewedCardMarkedConfident_advancesToTierZero() {
        XCTAssertEqual(FlashcardScheduling.nextTier(priorTier: -1, confident: true), 0)
    }

    func test_aConfidentReview_advancesOneTier() {
        XCTAssertEqual(FlashcardScheduling.nextTier(priorTier: 0, confident: true), 1)
        XCTAssertEqual(FlashcardScheduling.nextTier(priorTier: 1, confident: true), 2)
    }

    func test_aConfidentReviewAtTheLastTier_staysCappedThere() {
        let lastTier = FlashcardScheduling.intervalTiersDays.count - 1
        XCTAssertEqual(FlashcardScheduling.nextTier(priorTier: lastTier, confident: true), lastTier)
    }

    func test_anUnconfidentReview_alwaysResetsToTierZero() {
        XCTAssertEqual(FlashcardScheduling.nextTier(priorTier: 3, confident: false), 0)
        XCTAssertEqual(FlashcardScheduling.nextTier(priorTier: -1, confident: false), 0)
    }

    func test_nextDueDate_matchesTheRealIntervalScheduleInDays() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let dayInterval: TimeInterval = 24 * 60 * 60
        XCTAssertEqual(FlashcardScheduling.nextDueAt(now: now, tier: 0), now.addingTimeInterval(1 * dayInterval))
        XCTAssertEqual(FlashcardScheduling.nextDueAt(now: now, tier: 1), now.addingTimeInterval(3 * dayInterval))
        XCTAssertEqual(FlashcardScheduling.nextDueAt(now: now, tier: 4), now.addingTimeInterval(30 * dayInterval))
    }
}
