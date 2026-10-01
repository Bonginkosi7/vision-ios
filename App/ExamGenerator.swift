import Foundation
import VisionCore

/// Real AI-backed mock-test generation grounded in a processed document's
/// real extracted text — the App-layer orchestration half of
/// ExamGenerationLogic.swift (the prompt/parsing is pure VisionCore logic;
/// this is only the real network call glue, same split as
/// FlashcardGenerator.swift).
enum ExamGenerator {
    private static let providers: [CloudAIProvider] = [OpenAIProvider(), AnthropicProvider()]

    static func generate(documentText: String, counts: ExamGenerationCounts, topics: [TopicRef]) async -> StructuredResult<[RawExamQuestion]> {
        let bounded = ExamGenerationLogic.boundedText(documentText)
        guard !bounded.isEmpty else {
            return StructuredResult(ok: false, data: nil, error: "No processed material is available to generate a test from yet.", providerName: nil)
        }
        guard counts.total > 0 else {
            return StructuredResult(ok: false, data: nil, error: "Choose at least one question.", providerName: nil)
        }
        return await StructuredAI.generate(
            systemInstruction: ExamGenerationLogic.systemInstruction(counts: counts, topics: topics),
            userMessage: bounded,
            providers: providers,
            parse: { raw in ExamGenerationLogic.parseQuestions(raw, topics: topics) }
        )
    }
}
