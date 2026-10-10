import Foundation
import VisionCore

/// One batched AI call covering every still-unmarked short-answer question
/// in an attempt together — the App-layer orchestration half of
/// ShortAnswerMarkingLogic.swift, same real/pure split as
/// FlashcardGenerator.swift. Returns nil (leave everything pending, never
/// a fabricated mark) if unavailable or every attempt fails to parse.
enum ShortAnswerMarker {
    private static let providers: [CloudAIProvider] = [OpenAIProvider(), AnthropicProvider(), VisionCloudProvider()]

    static func mark(_ pending: [PendingShortAnswer]) async -> [ShortAnswerMarking]? {
        guard !pending.isEmpty else { return [] }
        let result = await StructuredAI.generate(
            systemInstruction: ShortAnswerMarkingLogic.systemInstruction(),
            userMessage: ShortAnswerMarkingLogic.prompt(for: pending),
            providers: providers,
            parse: { raw in ShortAnswerMarkingLogic.parseMarkings(raw, pending: pending) }
        )
        return result.ok ? result.data : nil
    }
}
