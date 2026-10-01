import XCTest
@testable import VisionCore

/// Direct port of RewardEligibilityTest.kt's real cases.
final class RewardEligibilityTests: XCTestCase {
    private let dailyLimitRule = RewardRule(category: .productivity, points: 5, label: "test", dailyLimit: 3)
    private let onceEverRule = RewardRule(category: .consistency, points: 20, label: "test", dedupe: .onceEver)
    private let onceDailyRule = RewardRule(category: .health, points: 10, label: "test", dedupe: .oncePerDay)
    private let plainRule = RewardRule(category: .learning, points: 3, label: "test")

    func test_aRuleWithNoDedupeOrLimit_isAlwaysEligible() {
        XCTAssertNil(RewardEligibility.evaluate(rule: plainRule, hasEventTypeToday: true, hasAwardForKey: true, countSinceStartOfToday: 999))
    }

    func test_oncePerDayRule_blocksASecondAwardTheSameDay() {
        let result = RewardEligibility.evaluate(rule: onceDailyRule, hasEventTypeToday: true, hasAwardForKey: false, countSinceStartOfToday: 0)
        XCTAssertEqual(result, .dedupe)
    }

    func test_oncePerDayRule_allowsTheFirstAwardOfTheDay() {
        XCTAssertNil(RewardEligibility.evaluate(rule: onceDailyRule, hasEventTypeToday: false, hasAwardForKey: false, countSinceStartOfToday: 0))
    }

    func test_onceEverRule_blocksWhenTheDedupeKeyAlreadyExists() {
        let result = RewardEligibility.evaluate(rule: onceEverRule, hasEventTypeToday: false, hasAwardForKey: true, countSinceStartOfToday: 0)
        XCTAssertEqual(result, .dedupe)
    }

    func test_dailyLimit_blocksOnceTheCountReachesTheLimit() {
        let result = RewardEligibility.evaluate(rule: dailyLimitRule, hasEventTypeToday: false, hasAwardForKey: false, countSinceStartOfToday: 3)
        XCTAssertEqual(result, .dailyLimit)
    }

    func test_dailyLimit_allowsAnAwardOneBelowTheLimit() {
        XCTAssertNil(RewardEligibility.evaluate(rule: dailyLimitRule, hasEventTypeToday: false, hasAwardForKey: false, countSinceStartOfToday: 2))
    }

    func test_dailyLimit_blocksEvenFurtherPastTheLimitNotJustAtTheBoundary() {
        let result = RewardEligibility.evaluate(rule: dailyLimitRule, hasEventTypeToday: false, hasAwardForKey: false, countSinceStartOfToday: 10)
        XCTAssertEqual(result, .dailyLimit)
    }
}
