import Foundation

/// Tidies the markdown the AI writes so a chat bubble reads cleanly: headings become bold lines, "-" / "*" lists
/// become bullets, and **bold** is kept for the screen to draw. Pure text, mirrored on Android.
public enum ChatText {
    public static func prepare(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map(prepareLine)
            .joined(separator: "\n")
    }

    private static func prepareLine(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // "### Step 6: Uploading" -> "**Step 6: Uploading**"
        if trimmed.hasPrefix("#") {
            let hashes = trimmed.prefix(while: { $0 == "#" })
            let rest = trimmed.dropFirst(hashes.count)
            if hashes.count <= 6, rest.first == " " {
                let title = rest.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "**", with: "")
                return title.isEmpty ? "" : "**\(title)**"
            }
        }
        // "- item" / "* item" -> "• item"
        if let first = trimmed.first, first == "-" || first == "*", trimmed.dropFirst().first == " " {
            return "• " + trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
        }
        return line
    }
}
