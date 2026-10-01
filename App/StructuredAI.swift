import Foundation
import VisionCore

struct StructuredResult<T> {
    let ok: Bool
    let data: T?
    let error: String?
    let providerName: String?
}

/// The one shared path any AI feature that needs a structured JSON result
/// should route through — direct port of StructuredAi.kt. Tries each
/// configured provider in order; on a parse failure, retries once against
/// the SAME provider with an explicit "respond again with only JSON"
/// follow-up, then moves to the next provider. Never fabricates a result:
/// if every attempt fails, returns an honest ok:false with a real reason.
enum StructuredAI {
    static func generate<T>(
        systemInstruction: String,
        userMessage: String,
        providers: [CloudAIProvider],
        parse: (String) -> T?
    ) async -> StructuredResult<T> {
        var attemptedAny = false

        for provider in providers {
            guard provider.isAvailable() else { continue }
            attemptedAny = true

            let first = await provider.generate(systemInstruction: systemInstruction, userMessage: userMessage, history: [])
            if first.ok, let text = first.text {
                if let parsed = parse(StructuredJSON.extractJsonText(text)) {
                    return StructuredResult(ok: true, data: parsed, error: nil, providerName: provider.name)
                }

                let retryMessage = """
                \(userMessage)

                ---
                Your previous response was:
                \(text)

                That wasn't valid JSON matching the required shape. Respond again with ONLY a single fenced ```json code block containing the corrected JSON — no other text before or after it.
                """
                let retry = await provider.generate(systemInstruction: systemInstruction, userMessage: retryMessage, history: [])
                if retry.ok, let retryText = retry.text, let retryParsed = parse(StructuredJSON.extractJsonText(retryText)) {
                    return StructuredResult(ok: true, data: retryParsed, error: nil, providerName: provider.name)
                }
            }
        }

        let error = attemptedAny
            ? "Cloud AI didn't return a usable response — this can happen on a slow connection or a busy provider. Try again."
            : "Cloud AI isn't configured — add an OpenAI or Anthropic API key in Settings to use this."
        return StructuredResult(ok: false, data: nil, error: error, providerName: nil)
    }
}
