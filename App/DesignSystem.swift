import SwiftUI

/// VISION's shared visual language: black and white, with restrained greys.
///
/// - Backgrounds are near-black; white carries primary text and the one
///   primary action on a screen; greys carry secondary text, borders and
///   quieter surfaces.
/// - Colour is reserved for state that means something: green for a
///   completed/successful state, red for failure or a blocked action. Nothing
///   is coloured for decoration.
/// - Icons appear only where they do work (a file type, a website's own
///   favicon, an action). No icon tiles, no emoji badges.
/// - Spacing comes from `Space`, corner radii from `Radius`; screens should use
///   those rather than ad-hoc numbers.
enum DesignSystem {
    // MARK: - Colour tokens
    static let bgCanvas = Color(hex: 0x0A0A0A)
    static let bgCard = Color(hex: 0x141414)
    /// Inputs, selected chips and other surfaces one step above a card.
    static let bgRaised = Color(hex: 0x1F1F1F)
    static let borderCard = Color(hex: 0x2A2A2A)
    /// The browser's address field: a clearly lighter grey than the bar behind it, so it reads as the thing to tap.
    static let addressField = Color(hex: 0x2E2E30)
    static let addressFieldBorder = Color(hex: 0x3D3D40)
    /// Secondary text. 9A9A9A on 0A0A0A is ~7:1, on 141414 ~6:1.
    static let textMuted2 = Color(hex: 0x9A9A9A)
    static let statusSuccess = Color(hex: 0x5BD08F)
    static let statusDangerText = Color(hex: 0xFF6B6B)

    // MARK: - Spacing and shape scale
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 12
        static let card: CGFloat = 16
    }

    // MARK: - Components

    /// A compact stat: big value over a muted label. Four of these sit across a row.
    @ViewBuilder
    static func statMiniCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(value).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 12)).foregroundStyle(textMuted2)
                .lineLimit(2).minimumScaleFactor(0.85)
        }
        // Same size for every card in a row whether the label wraps to one
        // line or two, with the numbers lined up along the top.
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .padding(Space.m)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(bgCard))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(borderCard, lineWidth: 1))
    }

    /// A one-pixel grey rule, for separating rows inside a card.
    @ViewBuilder
    static func divider() -> some View {
        Rectangle().fill(borderCard).frame(height: 1)
    }

    /// A label on the left and a real value on the right.
    @ViewBuilder
    static func statRow(label: String, value: String) -> some View {
        HStack(spacing: Space.m) {
            Text(label).font(.system(size: 15)).foregroundStyle(.white)
            Spacer()
            if !value.isEmpty {
                Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            }
        }
        .padding(.vertical, Space.m)
    }

    /// A hint card: bold title, muted body. No icon.
    @ViewBuilder
    static func tipCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Text(subtitle).font(.system(size: 14)).foregroundStyle(textMuted2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(bgCard))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(borderCard, lineWidth: 1))
    }

    /// A real (never fabricated-content) empty state: headline, one line of
    /// explanation, and a quiet outlined action.
    @ViewBuilder
    static func emptyState(title: String, subtitle: String, ctaText: String, onCta: @escaping () -> Void) -> some View {
        VStack(spacing: Space.l) {
            VStack(spacing: Space.s) {
                Text(title).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 14)).foregroundStyle(textMuted2)
            }
            .multilineTextAlignment(.center)
            secondaryButton(ctaText, onClick: onCta)
        }
        .padding(.vertical, Space.xxl).padding(.horizontal, Space.xl)
    }

    /// The one primary action on a screen: white pill, black label.
    @ViewBuilder
    static func primaryButton(_ text: String, fullWidth: Bool = false, onClick: @escaping () -> Void) -> some View {
        Button(action: onClick) {
            Text(text)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                .padding(.horizontal, Space.xl)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
                .background(Capsule().fill(Color.white))
        }
    }

    /// A quieter outlined pill for secondary actions.
    @ViewBuilder
    static func secondaryButton(_ text: String, fullWidth: Bool = false, onClick: @escaping () -> Void) -> some View {
        Button(action: onClick) {
            Text(text)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, Space.xl)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
                .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
        }
    }

    /// A quiet section heading: small, semibold, grey — content leads, labels follow.
    @ViewBuilder
    static func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .semibold)).tracking(0.4).foregroundStyle(textMuted2)
    }

    /// A generic rounded card container.
    @ViewBuilder
    static func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(bgCard))
            .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(borderCard, lineWidth: 1))
    }
}

extension View {
    /// The one text-input style: 44pt tall, raised-grey surface, white text.
    func visionField() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, DesignSystem.Space.m)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous).fill(DesignSystem.bgRaised))
            .foregroundStyle(.white)
    }

    /// Standard chrome for a full-screen VISION sheet: near-black canvas, a
    /// dark colour scheme and a matching navigation bar. These screens are
    /// dark-only by design (the brand theme is black and white).
    func visionScreen() -> some View {
        self
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .toolbarBackground(DesignSystem.bgCanvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
    }
}

/// The official VISION wordmark: the black-on-white artwork as a template
/// image, drawn white on the dark UI.
struct VisionWordmark: View {
    let height: CGFloat

    var body: some View {
        Image("VisionWordmark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .foregroundStyle(.white)
            .accessibilityLabel("Vision")
    }
}

/// The V from the official VISION logo (cropped from the same artwork, not
/// redrawn), as a template image drawn white.
struct VisionMark: View {
    let height: CGFloat

    var body: some View {
        Image("VisionMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .foregroundStyle(.white)
            .accessibilityLabel("Vision")
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
