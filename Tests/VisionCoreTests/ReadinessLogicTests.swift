import XCTest
@testable import VisionCore

/// Direct port of ReadinessLogic.kt's real cases (vision-android).
final class ReadinessLogicTests: XCTestCase {
    func test_noBookmarksYet_givesNilPercentNotZero() {
        let result = ReadinessLogic.compute(bookmarkUrls: [], offlineUrls: [], offlineCategories: [])
        XCTAssertNil(result.percent)
        XCTAssertEqual(result.bookmarkCount, 0)
        XCTAssertEqual(result.savedCount, 0)
        XCTAssertTrue(result.byCategory.isEmpty)
    }

    func test_someBookmarksNoneSavedOffline_givesZeroPercent() {
        let result = ReadinessLogic.compute(bookmarkUrls: ["a", "b"], offlineUrls: [], offlineCategories: [])
        XCTAssertEqual(result.percent, 0)
        XCTAssertEqual(result.bookmarkCount, 2)
        XCTAssertEqual(result.savedCount, 0)
    }

    func test_allBookmarksSavedOffline_givesHundredPercentAndCategoryBreakdown() {
        let result = ReadinessLogic.compute(
            bookmarkUrls: ["a", "b"],
            offlineUrls: ["a", "b", "c"],
            offlineCategories: ["news", "news", "sports"]
        )
        XCTAssertEqual(result.percent, 100)
        XCTAssertEqual(result.savedCount, 2)
        XCTAssertEqual(result.byCategory["news"], 2)
        XCTAssertEqual(result.byCategory["sports"], 1)
    }

    func test_partialPercentRoundsToNearestInteger() {
        let oneThird = ReadinessLogic.compute(bookmarkUrls: ["a", "b", "c"], offlineUrls: ["a"], offlineCategories: ["general"])
        XCTAssertEqual(oneThird.percent, 33)

        let twoThirds = ReadinessLogic.compute(bookmarkUrls: ["a", "b", "c"], offlineUrls: ["a", "b"], offlineCategories: ["general", "general"])
        XCTAssertEqual(twoThirds.percent, 67)
    }

    func test_offlineUrlNotMatchingAnyBookmarkDoesNotInflateSavedCount() {
        let result = ReadinessLogic.compute(bookmarkUrls: ["a"], offlineUrls: ["z"], offlineCategories: ["general"])
        XCTAssertEqual(result.savedCount, 0)
        XCTAssertEqual(result.percent, 0)
    }

    func test_duplicateBookmarkUrlsEachCountTowardSavedCount() {
        let result = ReadinessLogic.compute(bookmarkUrls: ["a", "a"], offlineUrls: ["a"], offlineCategories: ["general"])
        XCTAssertEqual(result.bookmarkCount, 2)
        XCTAssertEqual(result.savedCount, 2)
    }
}
