import Foundation
import VisionCore

/// Direct port of RewriteResult (RewriteWriter.kt).
struct RewriteResult {
    let ok: Bool
    let text: String?
    let providerName: String?
    let error: String?
}

/// Real AI-backed rewrite/grammar/simplify/professional/summarise — direct
/// port of RewriteWriter.kt. Tries cloud providers in the same declared
/// order as desktop's own `cloudProviders` array and Android's
/// `RewriteWriter.kt` (OpenAI first, then Anthropic) — a real, specific
/// order worth preserving exactly, not re-derived. When no provider is
/// configured or every configured one fails, returns an honest `ok:
/// false` with a real explanation, never a fabricated "rewritten" result
/// standing in for one.
enum RewriteWriter {
    private static let providers: [CloudAIProvider] = [OpenAIProvider(), AnthropicProvider(), VisionCloudProvider()]

    static func generate(text: String, action: RewriteAction) async -> RewriteResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return RewriteResult(ok: false, text: nil, providerName: nil, error: "Paste or type some text first.")
        }

        let configured = providers.filter { $0.isAvailable() }
        guard !configured.isEmpty else {
            return RewriteResult(
                ok: false, text: nil, providerName: nil,
                error: "No cloud AI provider is configured. Add an API key in Settings to use Rewrite Writer."
            )
        }

        let instruction = RewriteInstructions.forAction(action)
        var lastError: String?
        for provider in configured {
            let result = await provider.generate(systemInstruction: instruction, userMessage: trimmed, history: [])
            if result.ok {
                return RewriteResult(ok: true, text: result.text, providerName: result.providerName, error: nil)
            }
            lastError = result.error
        }
        return RewriteResult(ok: false, text: nil, providerName: nil, error: lastError ?? "All configured providers failed.")
    }
}
