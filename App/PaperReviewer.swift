import Foundation
import VisionCore

/// Real AI-backed review of a real document's real extracted text — the
/// App-layer orchestration half of PaperReviewLogic.swift (the prompt/
/// parsing is pure VisionCore logic; this is only the real network call
/// glue, same real/pure split as every other AI feature here).
enum PaperReviewer {
    private static let providers: [CloudAIProvider] = [OpenAIProvider(), AnthropicProvider()]

    static func review(documentText: String) async -> StructuredResult<PaperReview> {
        let bounded = PaperReviewLogic.boundedText(documentText)
        guard !bounded.isEmpty else {
            return StructuredResult(ok: false, data: nil, error: "This document has no extracted text to review yet.", providerName: nil)
        }
        return await StructuredAI.generate(
            systemInstruction: PaperReviewLogic.systemInstruction,
            userMessage: bounded,
            providers: providers,
            parse: PaperReviewLogic.parseReview
        )
    }
}
