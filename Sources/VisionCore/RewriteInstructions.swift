import Foundation

/// Direct port of RewriteAction (RewriteInstructions.kt).
public enum RewriteAction: String, CaseIterable, Identifiable {
    case rewrite, improveGrammar, simplify, professional, summarise

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .rewrite: return "Rewrite"
        case .improveGrammar: return "Improve grammar"
        case .simplify: return "Make simpler"
        case .professional: return "Make more professional"
        case .summarise: return "Summarise"
        }
    }
}

/// Verbatim port of RewriteInstructions.kt — the exact system prompt sent
/// to the cloud model for each action, unchanged (itself a verbatim port
/// of desktop's ACTION_INSTRUCTIONS in src/main/ai/rewriteWriter.ts). Pure
/// string logic, no network — real-verified without Xcode, same as every
/// other VisionCore file.
public enum RewriteInstructions {
    public static func forAction(_ action: RewriteAction) -> String {
        switch action {
        case .rewrite:
            return "Rewrite the user's text to say the same thing in different words, keeping the meaning and tone intact. Reply with ONLY the rewritten text — no preamble, no explanation, no quotation marks around it."
        case .improveGrammar:
            return "Correct the user's text for spelling and grammar only, preserving their own wording, tone, and meaning as closely as possible. Reply with ONLY the corrected text — no preamble, no explanation, no quotation marks around it."
        case .simplify:
            return "Rewrite the user's text to be simpler and easier to understand — shorter sentences, plainer words — while keeping the same meaning. Reply with ONLY the simplified text — no preamble, no explanation, no quotation marks around it."
        case .professional:
            return "Rewrite the user's text in a more professional, polished tone suitable for formal or workplace communication. Reply with ONLY the rewritten text — no preamble, no explanation, no quotation marks around it."
        case .summarise:
            return "Summarise the user's text concisely, capturing the key points. Reply with ONLY the summary — no preamble, no explanation, no quotation marks around it."
        }
    }
}
