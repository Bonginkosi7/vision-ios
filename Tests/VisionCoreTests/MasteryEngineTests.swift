import XCTest
@testable import VisionCore

final class MasteryEngineTests: XCTestCase {
    private let now = Date()

    private func daysAgo(_ days: Double) -> Date {
        now.addingTimeInterval(-days * 24 * 60 * 60)
    }

    func test_belowMinSamples_isAlwaysNotAssessed() {
        let events = [MasteryEvent(correct: true, createdAt: daysAgo(1)), MasteryEvent(correct: true, createdAt: daysAgo(1))]
        let mastery = MasteryEngine.computeTopicMastery(topicId: "t1", name: "A", level: 1, parentTopicId: nil, events: events, now: now)
        XCTAssertEqual(mastery.status, .notAssessed)
        XCTAssertEqual(mastery.sampleCount, 2)
    }

    func test_belowWeakThreshold_isWeak() {
        let events = [true, false, false, false, false].map { MasteryEvent(correct: $0, createdAt: daysAgo(1)) }
        let mastery = MasteryEngine.computeTopicMastery(topicId: "t2", name: "B", level: 1, parentTopicId: nil, events: events, now: now)
        XCTAssertEqual(mastery.masteryPercent, 20)
        XCTAssertEqual(mastery.status, .weak)
    }

    func test_atOrAboveStrongThreshold_isStrong() {
        let events = (0..<10).map { index in MasteryEvent(correct: index != 0, createdAt: daysAgo(1)) }
        let mastery = MasteryEngine.computeTopicMastery(topicId: "t3", name: "C", level: 1, parentTopicId: nil, events: events, now: now)
        XCTAssertEqual(mastery.masteryPercent, 90)
        XCTAssertEqual(mastery.status, .strong)
    }

    func test_betweenThresholds_isDeveloping() {
        let events = [true, true, true, false, false].map { MasteryEvent(correct: $0, createdAt: daysAgo(1)) }
        let mastery = MasteryEngine.computeTopicMastery(topicId: "t4", name: "D", level: 1, parentTopicId: nil, events: events, now: now)
        XCTAssertEqual(mastery.status, .developing)
    }

    func test_recencyWeighting_countsRecentEventsMoreThanOldOnes() {
        let events = [
            MasteryEvent(correct: false, createdAt: daysAgo(30)),
            MasteryEvent(correct: true, createdAt: daysAgo(1)),
            MasteryEvent(correct: true, createdAt: daysAgo(1)),
        ]
        let mastery = MasteryEngine.computeTopicMastery(topicId: "t5", name: "E", level: 1, parentTopicId: nil, events: events, now: now)
        XCTAssertEqual(mastery.masteryPercent, 80)
    }

    func test_lastActivityAt_tracksTheRealMostRecentEvent() {
        let mostRecent = daysAgo(1)
        let events = [MasteryEvent(correct: true, createdAt: daysAgo(10)), MasteryEvent(correct: true, createdAt: mostRecent), MasteryEvent(correct: false, createdAt: daysAgo(5))]
        let mastery = MasteryEngine.computeTopicMastery(topicId: "t6", name: "F", level: 1, parentTopicId: nil, events: events, now: now)
        XCTAssertEqual(mastery.lastActivityAt, mostRecent)
    }

    func test_zeroEvents_isZeroPercentAndNotAssessed() {
        let mastery = MasteryEngine.computeTopicMastery(topicId: "t7", name: "G", level: 1, parentTopicId: nil, events: [], now: now)
        XCTAssertEqual(mastery.masteryPercent, 0)
        XCTAssertEqual(mastery.status, .notAssessed)
        XCTAssertNil(mastery.lastActivityAt)
    }

    func test_rollupMastery_weightsBySampleCount() {
        let child1 = TopicMastery(topicId: "c1", name: "Sub1", level: 2, parentTopicId: "p1", sampleCount: 4, masteryPercent: 100, status: .strong, lastActivityAt: daysAgo(1))
        let child2 = TopicMastery(topicId: "c2", name: "Sub2", level: 2, parentTopicId: "p1", sampleCount: 1, masteryPercent: 0, status: .notAssessed, lastActivityAt: daysAgo(2))
        let rollup = MasteryEngine.rollupMastery(topicId: "p1", name: "Parent", level: 1, parentTopicId: nil, children: [child1, child2])
        XCTAssertEqual(rollup.masteryPercent, 80)
        XCTAssertEqual(rollup.sampleCount, 5)
        XCTAssertEqual(rollup.lastActivityAt, daysAgo(1))
    }

    func test_rollupMastery_withNoChildren_isZeroAndNotAssessed() {
        let rollup = MasteryEngine.rollupMastery(topicId: "p2", name: "ParentEmpty", level: 1, parentTopicId: nil, children: [])
        XCTAssertEqual(rollup.masteryPercent, 0)
        XCTAssertEqual(rollup.status, .notAssessed)
    }

    func test_listWeakTopics_filtersAndSortsAscending() {
        let weak20 = MasteryEngine.computeTopicMastery(topicId: "t2", name: "B", level: 1, parentTopicId: nil, events: [true, false, false, false, false].map { MasteryEvent(correct: $0, createdAt: daysAgo(1)) }, now: now)
        let weak25 = MasteryEngine.computeTopicMastery(topicId: "t8", name: "H", level: 1, parentTopicId: nil, events: [true, false, false, false].map { MasteryEvent(correct: $0, createdAt: daysAgo(1)) }, now: now)
        let strong = MasteryEngine.computeTopicMastery(topicId: "t3", name: "C", level: 1, parentTopicId: nil, events: (0..<10).map { i in MasteryEvent(correct: i != 0, createdAt: daysAgo(1)) }, now: now)
        let result = MasteryEngine.listWeakTopics([strong, weak25, weak20])
        XCTAssertEqual(result.map(\.topicId), ["t2", "t8"])
    }

    func test_listStrongTopics_filtersAndSortsDescending() {
        let strong90 = MasteryEngine.computeTopicMastery(topicId: "t3", name: "C", level: 1, parentTopicId: nil, events: (0..<10).map { i in MasteryEvent(correct: i != 0, createdAt: daysAgo(1)) }, now: now)
        let strong100 = MasteryEngine.computeTopicMastery(topicId: "t9", name: "I", level: 1, parentTopicId: nil, events: (0..<10).map { _ in MasteryEvent(correct: true, createdAt: daysAgo(1)) }, now: now)
        let weak = MasteryEngine.computeTopicMastery(topicId: "t2", name: "B", level: 1, parentTopicId: nil, events: [true, false, false, false, false].map { MasteryEvent(correct: $0, createdAt: daysAgo(1)) }, now: now)
        let result = MasteryEngine.listStrongTopics([weak, strong90, strong100])
        XCTAssertEqual(result.map(\.topicId), ["t9", "t3"])
    }
}
