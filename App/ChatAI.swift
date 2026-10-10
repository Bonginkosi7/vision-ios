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
/// TutorAI.swift. The on-device model (LocalLLM, llama.cpp) is the last
/// provider — the counterpart of Android's local-model fallback — so a
/// configured cloud key still wins and the local model answers when none
/// is set or the network is down. If it hasn't been downloaded, the
/// honest "not configured" reply below explains how to get an answer.
enum ChatAI {
    private static let providers: [CloudAIProvider] = [AnthropicProvider(), OpenAIProvider(), LocalModelProvider()]

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
            text: "VISION can't answer free-form questions yet: the offline model isn't downloaded and no cloud AI is configured. Download the offline model, or add an OpenAI or Anthropic API key, in Settings.",
            category: category,
            providerName: nil
        )
    }
}
