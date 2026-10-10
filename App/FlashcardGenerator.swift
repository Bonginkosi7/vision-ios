import Foundation
import VisionCore

/// Real AI-backed flashcard generation grounded in a processed document's
/// real extracted text — the App-layer orchestration half of
/// FlashcardGenerationLogic.kt (the prompt/parsing is pure VisionCore
/// logic; this is only the real network call glue, same split as
/// TopicExtractor.swift).
enum FlashcardGenerator {
    private static let providers: [CloudAIProvider] = [OpenAIProvider(), AnthropicProvider(), VisionCloudProvider()]

    static func generate(documentText: String, count: Int, topics: [TopicRef]) async -> StructuredResult<[RawFlashcard]> {
        let bounded = FlashcardGenerationLogic.boundedText(documentText)
        guard !bounded.isEmpty else {
            return StructuredResult(ok: false, data: nil, error: "No processed material is available to generate flashcards from yet.", providerName: nil)
        }
        let clampedCount = FlashcardGenerationLogic.clampCount(count)
        return await StructuredAI.generate(
            systemInstruction: FlashcardGenerationLogic.systemInstruction(count: clampedCount, topics: topics),
            userMessage: bounded,
            providers: providers,
            parse: { raw in FlashcardGenerationLogic.parseFlashcards(raw, topics: topics) }
        )
    }
}
