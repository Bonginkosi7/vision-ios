import Foundation
import VisionCore

/// Real AI-backed topic extraction grounded in a processed document's
/// real extracted text — the App-layer orchestration half of
/// TopicExtractionLogic.kt (the prompt/parsing is pure VisionCore logic;
/// this is only the real network call glue, same split as
/// RewriteWriter.swift/RewriteInstructions.swift).
enum TopicExtractor {
    private static let providers: [CloudAIProvider] = [OpenAIProvider(), AnthropicProvider()]

    static func extract(documentText: String) async -> StructuredResult<[RawTopic]> {
        let bounded = TopicExtractionLogic.boundedText(documentText)
        guard !bounded.isEmpty else {
            return StructuredResult(ok: false, data: nil, error: "No processed material is available to identify topics from yet.", providerName: nil)
        }
        return await StructuredAI.generate(
            systemInstruction: TopicExtractionLogic.systemInstruction,
            userMessage: bounded,
            providers: providers,
            parse: TopicExtractionLogic.parseTopics
        )
    }
}
