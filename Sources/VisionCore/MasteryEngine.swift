import Foundation

public enum MasteryStatus: String, Equatable, CaseIterable {
    case weak = "WEAK"
    case developing = "DEVELOPING"
    case strong = "STRONG"
    case notAssessed = "NOT_ASSESSED"
}

public struct TopicMastery: Identifiable, Equatable {
    public let topicId: String
    public let name: String
    public let level: Int
    public let parentTopicId: String?
    public let sampleCount: Int
    public let masteryPercent: Int
    public let status: MasteryStatus
    public let lastActivityAt: Date?
    public var id: String { topicId }

    public init(topicId: String, name: String, level: Int, parentTopicId: String?, sampleCount: Int, masteryPercent: Int, status: MasteryStatus, lastActivityAt: Date?) {
        self.topicId = topicId; self.name = name; self.level = level; self.parentTopicId = parentTopicId
        self.sampleCount = sampleCount; self.masteryPercent = masteryPercent; self.status = status; self.lastActivityAt = lastActivityAt
    }
}

public struct MasteryEvent: Equatable {
    public let correct: Bool
    public let createdAt: Date
    public init(correct: Bool, createdAt: Date) { self.correct = correct; self.createdAt = createdAt }
}

/// Direct port of MasteryEngine.kt (itself a port of desktop's
/// masteryEngine.ts) — same thresholds, same recency-weighted
/// correct/total ratio across both flashcard reviews and marked exam
/// answers together, same honest "notAssessed" floor below `minSamples`
/// real data points rather than overclaiming mastery off one data point.
/// `now` is an explicit parameter (not read internally), same testability
/// pattern already established for `FlashcardScheduling.nextDueAt`.
public enum MasteryEngine {
    private static let weakThreshold = 60
    private static let strongThreshold = 85
    private static let minSamples = 3
    private static let recencyWindow: TimeInterval = 14 * 24 * 60 * 60
    private static let recentWeight = 2
    private static let oldWeight = 1

    private static func status(masteryPercent: Int, sampleCount: Int) -> MasteryStatus {
        if sampleCount < minSamples { return .notAssessed }
        if masteryPercent < weakThreshold { return .weak }
        if masteryPercent >= strongThreshold { return .strong }
        return .developing
    }

    public static func computeTopicMastery(topicId: String, name: String, level: Int, parentTopicId: String?, events: [MasteryEvent], now: Date = Date()) -> TopicMastery {
        var weightedCorrect = 0
        var weightedTotal = 0
        var lastActivityAt: Date?

        for event in events {
            let weight = now.timeIntervalSince(event.createdAt) <= recencyWindow ? recentWeight : oldWeight
            weightedTotal += weight
            if event.correct { weightedCorrect += weight }
            if lastActivityAt == nil || event.createdAt > lastActivityAt! { lastActivityAt = event.createdAt }
        }

        let masteryPercent = weightedTotal > 0 ? Int((Double(weightedCorrect) / Double(weightedTotal) * 100).rounded()) : 0
        return TopicMastery(
            topicId: topicId, name: name, level: level, parentTopicId: parentTopicId,
            sampleCount: events.count, masteryPercent: masteryPercent,
            status: status(masteryPercent: masteryPercent, sampleCount: events.count), lastActivityAt: lastActivityAt
        )
    }

    /// A parent topic's mastery, rolled up from its subtopics' already-
    /// computed mastery — weighted by each subtopic's own `sampleCount`,
    /// so subtopics with more real evidence count more.
    public static func rollupMastery(topicId: String, name: String, level: Int, parentTopicId: String?, children: [TopicMastery]) -> TopicMastery {
        let totalSamples = children.reduce(0) { $0 + $1.sampleCount }
        let masteryPercent: Int
        if totalSamples > 0 {
            let weightedSum = children.reduce(0) { $0 + $1.masteryPercent * $1.sampleCount }
            masteryPercent = Int((Double(weightedSum) / Double(totalSamples)).rounded())
        } else {
            masteryPercent = 0
        }
        let lastActivityAt = children.compactMap { $0.lastActivityAt }.max()

        return TopicMastery(
            topicId: topicId, name: name, level: level, parentTopicId: parentTopicId,
            sampleCount: totalSamples, masteryPercent: masteryPercent,
            status: status(masteryPercent: masteryPercent, sampleCount: totalSamples), lastActivityAt: lastActivityAt
        )
    }

    public static func listWeakTopics(_ all: [TopicMastery]) -> [TopicMastery] {
        all.filter { $0.status == .weak }.sorted { $0.masteryPercent < $1.masteryPercent }
    }

    public static func listStrongTopics(_ all: [TopicMastery]) -> [TopicMastery] {
        all.filter { $0.status == .strong }.sorted { $0.masteryPercent > $1.masteryPercent }
    }
}
