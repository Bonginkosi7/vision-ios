import Foundation
import VisionCore

/// Real per-topic mastery aggregation — the App-layer orchestration half
/// of MasteryEngine.swift, direct port of PerformanceLogic.kt (itself the
/// Android counterpart of desktop's performanceService.ts). Combines real
/// flashcard-review events and real marked-exam-answer events for each
/// topic, feeds them through `MasteryEngine`, and rolls level-1 topics up
/// from their level-2 subtopics' own already-computed mastery — same
/// shape as desktop's computeMasteryForDocument.
///
/// `masteryForTopic` closes the trim this file's doc comment used to
/// describe: Study Plan (Phase 13) now exists and is the real consumer
/// of a single topic's mastery for `StudySessionLogic`'s before/after
/// delta.
///
/// `getWeakTopics`/`getStrongTopics` are still not ported: real, but
/// genuinely unused even in Android's own PerformanceLogic.kt — nothing
/// there calls them either, and `PerformanceView` gets the same result
/// by filtering its own already-computed `allTopics` via
/// `MasteryEngine.listWeakTopics`/`listStrongTopics` directly, matching
/// `PerformanceActivity.kt`'s own `renderPerformance()`.
struct PerformanceCalculator {
    let topicStore: TopicStore
    let flashcardStore: FlashcardStore
    let examStore: ExamStore
    let studyDocumentStore: StudyDocumentStore

    private func events(forTopic topicId: String) -> [MasteryEvent] {
        let reviewEvents = (try? flashcardStore.reviewEventsForTopic(topicId)) ?? []
        let examEvents = (try? examStore.markedAnswersForTopic(topicId)) ?? []
        return reviewEvents + examEvents
    }

    func computeMasteryForDocument(_ documentId: String) -> [TopicMastery] {
        let topics = (try? topicStore.listForDocument(documentId)) ?? []
        let level1 = topics.filter { $0.level == 1 }
        let level2 = topics.filter { $0.level == 2 }

        var level2Mastery: [String: TopicMastery] = [:]
        for topic in level2 {
            level2Mastery[topic.id] = MasteryEngine.computeTopicMastery(
                topicId: topic.id, name: topic.name, level: topic.level, parentTopicId: topic.parentTopicId,
                events: events(forTopic: topic.id)
            )
        }

        var result: [TopicMastery] = Array(level2Mastery.values)
        for topic in level1 {
            let ownMastery = MasteryEngine.computeTopicMastery(
                topicId: topic.id, name: topic.name, level: topic.level, parentTopicId: topic.parentTopicId,
                events: events(forTopic: topic.id)
            )
            let children = level2.filter { $0.parentTopicId == topic.id }.compactMap { level2Mastery[$0.id] }
            if children.isEmpty {
                result.append(ownMastery)
            } else {
                result.append(MasteryEngine.rollupMastery(topicId: topic.id, name: topic.name, level: topic.level, parentTopicId: topic.parentTopicId, children: [ownMastery] + children))
            }
        }
        return result
    }

    func computeMasteryForAllDocuments() -> [TopicMastery] {
        let documents = (try? studyDocumentStore.list()) ?? []
        return documents.flatMap { computeMasteryForDocument($0.id) }
    }

    /// A single topic's real current mastery, independent of which
    /// document it belongs to — used by `StudySessionManager` for the
    /// real before/after mastery delta on a study session.
    func masteryForTopic(_ topicId: String) -> TopicMastery? {
        guard let fetched = try? topicStore.get(topicId), let topic = fetched else { return nil }
        return MasteryEngine.computeTopicMastery(topicId: topic.id, name: topic.name, level: topic.level, parentTopicId: topic.parentTopicId, events: events(forTopic: topic.id))
    }
}
