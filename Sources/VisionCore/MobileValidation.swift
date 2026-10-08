import Foundation

/// Direct port of MobileValidation.kt (itself a port of desktop's
/// isValidSouthAfricanMobileNumber/maskMobileNumber in
/// src/shared/rewardsCatalog.ts) — real, not decorative: every SA mobile
/// number is 10 digits starting with 0, or +27 + 9 digits.
public enum MobileValidation {
    private static let localFormat = try! NSRegularExpression(pattern: "^0\\d{9}$")
    private static let intlFormat = try! NSRegularExpression(pattern: "^\\+27\\d{9}$")

    public static func isValidSouthAfricanMobileNumber(_ raw: String) -> Bool {
        let digits = raw.replacingOccurrences(of: "[\\s-]", with: "", options: .regularExpression)
        let range = NSRange(digits.startIndex..., in: digits)
        return localFormat.firstMatch(in: digits, range: range) != nil
            || intlFormat.firstMatch(in: digits, range: range) != nil
    }

    /// "082 345 6789" -> "082 ••• 6789" — enough to recognize your own
    /// number, not enough to expose it in a list.
    public static func maskMobileNumber(_ raw: String) -> String {
        let digits = raw.replacingOccurrences(of: "[\\s-]", with: "", options: .regularExpression)
        guard digits.count >= 6 else { return "•••" }
        let prefix = digits.prefix(3)
        let suffix = digits.suffix(4)
        return "\(prefix) ••• \(suffix)"
    }
}
