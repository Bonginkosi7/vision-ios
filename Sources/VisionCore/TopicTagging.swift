import Foundation

/// A minimal, pure reference to a real extracted topic — just enough for
/// TopicTagging's prompt-building/name-resolution, deliberately decoupled
/// from the GRDB-backed Topic record (App/TopicStore.swift) the same way
/// RawTopic already is, so this logic stays verifiable without Xcode.
public struct TopicRef: Equatable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Shared "tag AI-generated flashcards/exam questions with a real
/// extracted topic" logic — direct port of TopicTagging.kt. Desktop
/// resolves this via real per-chunk topic linkage that this app's
/// whole-document-text grounding has no equivalent for; instead, when a
/// document has real extracted topics, the AI is asked to name the
/// closest-matching one per generated item, and that name is resolved
/// back to a real topicId here in code. An AI response naming a topic
/// that isn't in the real list resolves to nil rather than being
/// trusted — never a fabricated id.
public enum TopicTagging {
    /// Empty when the document has no real extracted topics yet —
    /// callers should skip asking for a topic name entirely in that case.
    public static func promptFragment(_ topics: [TopicRef]) -> String {
        guard !topics.isEmpty else { return "" }
        let names = topics.map { "- \($0.name)" }.joined(separator: "\n")
        return "\n\nThis document's known topics are:\n\(names)\n\nFor each item you generate, also include \"topicName\" set to the closest matching topic name from this exact list, or null if none genuinely fit. Only use a name from this list verbatim — never invent a new one."
    }

    public static func resolveTopicId(_ topicName: String?, _ topics: [TopicRef]) -> String? {
        guard let topicName else { return nil }
        let trimmed = topicName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return topics.first { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }?.id
    }
}
