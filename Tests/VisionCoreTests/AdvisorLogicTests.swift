import XCTest
@testable import VisionCore

final class AdvisorLogicTests: XCTestCase {
    func test_belowThreshold_returnsNoSuggestion() {
        XCTAssertNil(AdvisorLogic.getSuggestion(continuousSessionMs: 44 * 60 * 1000))
    }

    func test_atOrAboveThreshold_returnsARealSuggestionWithThreeActions() {
        let suggestion = AdvisorLogic.getSuggestion(continuousSessionMs: 45 * 60 * 1000)
        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.actions.count, 3)
        XCTAssertEqual(suggestion?.actions.map { $0.id }, [.takeBreak, .fiveMinReset, .dismiss])
    }

    func test_suggestionMessage_mentionsTheRealElapsedMinutes() {
        let suggestion = AdvisorLogic.getSuggestion(continuousSessionMs: 60 * 60 * 1000)
        XCTAssertEqual(suggestion?.message, "You've been active for 60 minutes. A short break may help you reset your attention.")
    }
}
