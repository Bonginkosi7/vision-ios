import Foundation

public struct RawFlashcard: Equatable {
    public let front: String
    public let back: String
    public let topicId: String?

    public init(front: String, back: String, topicId: String? = nil) {
        self.front = front
        self.back = back
        self.topicId = topicId
    }
}

/// Real AI-backed flashcard generation grounded in a processed document's
/// real extracted text — direct port of FlashcardGenerationLogic.kt. Pure
/// prompt-building and response-parsing only; the actual AI call lives in
/// App/FlashcardGenerator.swift, the same real/pure split
/// TopicExtractionLogic/TopicExtractor already established.
public enum FlashcardGenerationLogic {
    private static let maxChars = 12_000
    private static let minCount = 1
    private static let maxCount = 50

    public static func systemInstruction(count: Int, topics: [TopicRef]) -> String {
        let base = """
        You are generating real flashcards for VISION from a student's own uploaded study material. You will be given the real text of that material. Generate exactly \(count) flashcards, each grounded in the given text — never invent facts not present in it.

        Respond with ONLY a single fenced ```json code block containing an object of exactly this shape, nothing else:
        {"flashcards":[{"front":"a real question or prompt","back":"the real answer"}]}
        """
        return base + TopicTagging.promptFragment(topics)
    }

    public static func boundedText(_ documentText: String) -> String {
        String(documentText.prefix(maxChars)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func clampCount(_ count: Int) -> Int {
        min(max(count, minCount), maxCount)
    }

    public static func parseFlashcards(_ raw: String, topics: [TopicRef]) -> [RawFlashcard]? {
        guard
            let data = raw.data(using: .utf8),
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let array = obj["flashcards"] as? [[String: Any]]
        else { return nil }

        var cards: [RawFlashcard] = []
        for c in array {
            let front = (c["front"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let back = (c["back"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !front.isEmpty, !back.isEmpty else { continue }
            let topicId = TopicTagging.resolveTopicId(c["topicName"] as? String, topics)
            cards.append(RawFlashcard(front: front, back: back, topicId: topicId))
        }
        return cards.isEmpty ? nil : cards
    }
}
