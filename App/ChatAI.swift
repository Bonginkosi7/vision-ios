import Foundation
import VisionCore

struct ChatAnswer {
    let text: String
    let category: TaskCategory
    let providerName: String?
}

/// Real AI-backed chat — the App-layer orchestration half of
/// ChatCategoryLogic.swift (the classification/instruction-building is
/// pure VisionCore logic; this is only the real network call glue).
/// Classifies the message locally, then tries each configured cloud
/// provider in order — same real/pure split and provider-loop shape as
/// TutorAI.swift. Android's local-model fallback (`LocalModelManager`)
/// is deliberately NOT ported — no on-device model exists on iOS yet
/// (see README's disclosed scope trim); the honest "not configured"
/// reply covers the same ground TutorLogic's own already does.
enum ChatAI {
    private static let providers: [CloudAIProvider] = [AnthropicProvider(), OpenAIProvider()]

    static func ask(message: String, history: [ChatMessage]) async -> ChatAnswer {
        let category = ChatCategoryLogic.classify(message)
        let instruction = ChatCategoryLogic.buildSystemInstruction(category: category)
        let trimmedHistory = ChatCategoryLogic.trimmedHistory(history)

        for provider in providers {
            guard provider.isAvailable() else { continue }
            let result = await provider.generate(systemInstruction: instruction, userMessage: message, history: trimmedHistory)
            if result.ok, let text = result.text {
                return ChatAnswer(text: text, category: category, providerName: provider.name)
            }
        }

        return ChatAnswer(
            text: "VISION doesn't have a local AI model installed, and no cloud AI is configured right now, so it can't generate a free-form answer. Add an OpenAI or Anthropic API key in Settings to chat with me.",
            category: category,
            providerName: nil
        )
    }
}
