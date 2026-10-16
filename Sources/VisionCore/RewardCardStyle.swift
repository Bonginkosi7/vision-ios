import Foundation

/// The two gradient colours of a reward card, by category — the same ones the desktop Redeem page uses.
public enum RewardCardStyle {
    public struct Colors: Equatable, Sendable {
        public let start: UInt32
        public let end: UInt32
    }

    private static let byCategory: [String: Colors] = [
        "connectivity": Colors(start: 0x1E3A8A, end: 0x0891B2),
        "lifestyle": Colors(start: 0x7C4A1E, end: 0xB45309),
        "entertainment": Colors(start: 0x581C87, end: 0xBE185D),
        "education": Colors(start: 0x164E63, end: 0x0E7490),
        "wellbeing": Colors(start: 0x14532D, end: 0x15803D),
        "shopping": Colors(start: 0x831843, end: 0x7C3AED),
    ]

    /// An unknown category falls back to the lifestyle colours rather than an unstyled card.
    public static func colors(forCategory category: String) -> Colors {
        byCategory[category.lowercased()] ?? byCategory["lifestyle"]!
    }
}
