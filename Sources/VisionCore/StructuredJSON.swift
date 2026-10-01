import Foundation

/// Shared "pull the JSON out of a fenced ```json block" logic — direct
/// port of StructuredAi.kt's extractJsonText, used by any AI feature that
/// needs a structured JSON result back from a model that sometimes wraps
/// its answer in prose or a fenced code block instead of raw JSON.
public enum StructuredJSON {
    private static let jsonFenceRegex = try! NSRegularExpression(
        pattern: "```(?:json)?\\s*([\\s\\S]*?)```", options: [.caseInsensitive]
    )

    public static func extractJsonText(_ raw: String) -> String {
        let fullRange = NSRange(raw.startIndex..., in: raw)
        guard
            let match = jsonFenceRegex.firstMatch(in: raw, range: fullRange),
            let groupRange = Range(match.range(at: 1), in: raw)
        else {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(raw[groupRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
