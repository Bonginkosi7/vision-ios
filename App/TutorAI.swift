import Foundation
import VisionCore

/// Real AI-backed tutoring — the App-layer orchestration half of
/// TutorLogic.swift (the prompt-building is pure VisionCore logic; this is
/// only the real network call glue). Unlike StructuredAI's callers, this
/// tries each configured provider in order and returns the first real
/// free-text reply — there's no structured JSON to parse or retry here,
/// so this is a simpler loop than StructuredAI.generate, not a reuse of it.
enum TutorAI {
    private static let providers: [CloudAIProvider] = [OpenAIProvider(), AnthropicProvider()]

    static func ask(question: String, history: [ChatMessage], documentText: String?) async -> TutorAnswer {
        let (instruction, grounded) = TutorLogic.systemInstruction(documentText: documentText)
        let trimmedHistory = TutorLogic.trimmedHistory(history)

        for provider in providers {
            guard provider.isAvailable() else { continue }
            let result = await provider.generate(systemInstruction: instruction, userMessage: question, history: trimmedHistory)
            if result.ok, let text = result.text {
                return TutorAnswer(text: text, groundedInDocument: grounded, providerName: provider.name)
            }
        }

        return TutorLogic.unconfiguredAnswer
    }
}
