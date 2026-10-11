import Foundation

/// Port of desktop's passwordGenerator.ts (and Android's PasswordGeneratorLogic.kt) — same character
/// pools without the visually ambiguous characters, at least one character from each class, and a real
/// Fisher-Yates shuffle. `SystemRandomNumberGenerator` is Apple's cryptographically secure source.
public enum PasswordGenerator {
    private static let lower = Array("abcdefghijkmnopqrstuvwxyz") // no 'l' — looks like '1'/'I'
    private static let upper = Array("ABCDEFGHJKLMNPQRSTUVWXYZ") // no 'I'/'O' — look like '1'/'0'
    private static let digits = Array("23456789") // no '0'/'1'
    private static let symbols = Array("!@#$%^&*-_=+")
    private static let all = lower + upper + digits + symbols

    public static func generate(length: Int = 20) -> String {
        generate(length: length, using: &systemGenerator)
    }

    public static func generate<G: RandomNumberGenerator>(length: Int = 20, using generator: inout G) -> String {
        let bounded = max(8, length)
        var chars: [Character] = [
            lower.randomElement(using: &generator)!,
            upper.randomElement(using: &generator)!,
            digits.randomElement(using: &generator)!,
            symbols.randomElement(using: &generator)!,
        ]
        for _ in 0..<(bounded - chars.count) { chars.append(all.randomElement(using: &generator)!) }
        chars.shuffle(using: &generator)
        return String(chars)
    }

    private static var systemGenerator = SystemRandomNumberGenerator()
}
