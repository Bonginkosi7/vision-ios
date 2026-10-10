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

    /// Largest slice of an attached file's text each kind of provider gets.
    /// The on-device model reads about 2,000 tokens at once, shared with the
    /// question and its answer, so it gets far less than a cloud model.
    private static let cloudAttachmentLimit = 24_000
    private static let localAttachmentLimit = 3_500

    static func ask(message: String, history: [ChatMessage], attachment: ChatAttachment? = nil) async -> ChatAnswer {
        let category = ChatCategoryLogic.classify(message)
        let instruction = ChatCategoryLogic.buildSystemInstruction(category: category)
        let trimmedHistory = ChatCategoryLogic.trimmedHistory(history)

        for provider in providers {
            guard provider.isAvailable() else { continue }
            let isLocal = provider is LocalModelProvider
            let limit = isLocal ? localAttachmentLimit : cloudAttachmentLimit
            let composed = attachment.map { $0.compose(question: message, limit: limit) }
            let result = await provider.generate(systemInstruction: instruction, userMessage: composed?.prompt ?? message, history: trimmedHistory)
            if result.ok, var text = result.text {
                if composed?.truncated == true {
                    text += isLocal
                        ? "\n\n(Only the first part of the file fit in the on-device model. For a long document, add a cloud AI key in Settings.)"
                        : "\n\n(The file was very long, so only the first part was read.)"
                }
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

/// A file the user attached to a question: its extracted plain text only.
struct ChatAttachment: Equatable {
    let name: String
    let text: String

    /// The prompt sent to the model: the file's text (cut to `limit`
    /// characters) followed by the question.
    func compose(question: String, limit: Int) -> (prompt: String, truncated: Bool) {
        let body = String(text.prefix(limit))
        let prompt = "Here is the content of the file \"\(name)\":\n\n\(body)\n\n---\nUsing only that file, answer: \(question)"
        return (prompt, text.count > limit)
    }
}

/// Reads the text out of a PDF, Word, or plain-text file the user picked.
enum AttachmentReader {
    static func text(from url: URL) throws -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return try PdfExtractor().extract(fileURL: url)
        case "docx": return try DocxExtractor().extract(fileURL: url)
        case "txt", "text", "md": return try TxtExtractor().extract(fileURL: url)
        default: throw DocumentExtractionError.unreadable("VISION can read PDF, Word (.docx) and text files.")
        }
    }
}
