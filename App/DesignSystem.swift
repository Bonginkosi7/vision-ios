import SwiftUI

/// Reusable pieces of the reconstructed design system, ported from
/// DesignSystem.kt (vision-android) — same component list, same color
/// tokens (copied verbatim from vision-android's colors.xml), same
/// "reconstructed by eye from real reference screenshots" origin. SwiftUI
/// expresses each Android drawable (bg_card_rounded, bg_pill_button_primary,
/// etc.) as an inline background modifier here instead of a separate
/// drawable XML file — a real simplification versus Android, not a silent
/// divergence.
enum DesignSystem {
    // MARK: - Color tokens (vision-android colors.xml, verbatim)
    static let visionPurple = Color(hex: 0x7B3FF2)
    static let visionBlue = Color(hex: 0x3B6FFF)
    static let bgCanvas = Color(hex: 0x0A0D16)
    static let bgCard = Color(hex: 0x131829)
    static let borderCard = Color(hex: 0x1E2436)
    static let textMuted2 = Color(hex: 0x8890A6)
    static let statusSuccess = Color(hex: 0x3ECF8E)
    static let statusDangerText = Color(hex: 0xFF8FA3)
    static let statDotOrange = Color(hex: 0xF5A623)

    static let brandGradient = LinearGradient(
        colors: [visionPurple, visionBlue], startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // MARK: - Components

    /// The gradient rounded-square page/stat icon, holding one emoji glyph.
    @ViewBuilder
    static func iconBadge(_ emoji: String, size: CGFloat = 40, textSize: CGFloat = 18) -> some View {
        Text(emoji)
            .font(.system(size: textSize))
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.3).fill(brandGradient))
    }

    /// A horizontally-scrolling row of filter pills, each with a real count badge.
    @ViewBuilder
    static func filterChipRow(options: [(label: String, count: Int)], selected: Int, onSelect: @escaping (Int) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button(action: { onSelect(index) }) {
                        HStack(spacing: 8) {
                            Text(option.label).foregroundStyle(.white).font(.system(size: 13))
                            Text("\(option.count)")
                                .font(.system(size: 11))
                                .foregroundStyle(.white)
                                .frame(minWidth: 20)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.black.opacity(0.2)))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            Capsule().fill(index == selected ? AnyShapeStyle(brandGradient) : AnyShapeStyle(bgCard))
                        )
                        .overlay(Capsule().stroke(index == selected ? Color.clear : borderCard, lineWidth: 1))
                    }
                }
            }
        }
    }

    /// One 4-across mini stat card — a real icon badge, a big value, a muted label.
    @ViewBuilder
    static func statMiniCard(emoji: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            iconBadge(emoji, size: 28, textSize: 13)
            Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            Text(label).font(.system(size: 11)).foregroundStyle(textMuted2)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(bgCard))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderCard, lineWidth: 1))
    }

    /// A bordered row inside a card: icon, label, and a real value pill on the trailing end.
    @ViewBuilder
    static func statRow(emoji: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            iconBadge(emoji, size: 32, textSize: 14)
            Text(label).font(.system(size: 14)).foregroundStyle(.white)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 13)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.2)))
            }
        }
        .padding(.vertical, 10)
    }

    /// The bottom hint card — icon, bold title, muted subtitle, trailing chevron.
    @ViewBuilder
    static func tipCard(emoji: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            iconBadge(emoji, size: 36, textSize: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(textMuted2)
            }
            Spacer()
            Text("›").font(.system(size: 18)).foregroundStyle(textMuted2)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(bgCard))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderCard, lineWidth: 1))
    }

    /// A real (never fabricated-content) empty state: illustration square, headline, subtext, CTA.
    @ViewBuilder
    static func emptyState(emoji: String, title: String, subtitle: String, ctaText: String, onCta: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Text(emoji)
                .font(.system(size: 40))
                .frame(width: 96, height: 96)
                .background(RoundedRectangle(cornerRadius: 16).fill(bgCard))
            VStack(spacing: 6) {
                Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(textMuted2)
            }
            .multilineTextAlignment(.center)
            Button(action: onCta) {
                Text("+  \(ctaText)")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Capsule().fill(brandGradient))
            }
        }
        .padding(.vertical, 32).padding(.horizontal, 24)
    }

    /// A small status pill — e.g. a "Blocked"-style indicator.
    @ViewBuilder
    static func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11)).foregroundStyle(statusDangerText)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(statusDangerText.opacity(0.16)))
    }

    /// A full-width or wrap-content primary pill button/CTA.
    @ViewBuilder
    static func primaryButton(_ text: String, onClick: @escaping () -> Void) -> some View {
        Button(action: onClick) {
            Text(text)
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Capsule().fill(brandGradient))
        }
    }

    /// A bold section label — "This Week", "How you earn points", etc.
    @ViewBuilder
    static func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
    }

    /// A generic rounded card container.
    @ViewBuilder
    static func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(bgCard))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderCard, lineWidth: 1))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
