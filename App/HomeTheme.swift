import SwiftUI
import VisionCore

/// Every place the homepage can send the user. Each maps to an existing
/// screen in MainBrowserView — nothing here is a new destination.
enum HomeDestination {
    case advisor, settings, overview, points, visionReady
    case offlineLibrary, tasks, focus, flashcards
}

/// Black-and-white palette for the homepage only. Deliberately local to the
/// homepage rather than changing `DesignSystem`, whose colours the rest of the
/// app (every other screen) still uses.
enum HomeTheme {
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.68)
    static let textTertiary = Color.white.opacity(0.46)
    static let fill = Color.white.opacity(0.07)
    static let stroke = Color.white.opacity(0.14)
    static let divider = Color.white.opacity(0.10)
    static let cardRadius: CGFloat = 20
}

extension View {
    /// Rounded translucent-black card with a hairline border and a soft shadow.
    func homeCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HomeTheme.cardRadius, style: .continuous)
                    .fill(Color.black.opacity(0.42))
                    .overlay(
                        RoundedRectangle(cornerRadius: HomeTheme.cardRadius, style: .continuous).fill(HomeTheme.fill)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: HomeTheme.cardRadius, style: .continuous)
                    .stroke(HomeTheme.stroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}

/// Online / Offline segmented toggle. Which segment is active comes from
/// `HomeConnectivityMode` (real reachability + the user's saved choice), never
/// from local view state, so it can't show Online while the device has no
/// connection. Green means Online, red means Offline — whether that's the
/// user's choice or a real loss of connection; the status line under the
/// greeting says which.
///
/// Both labels are pinned to a single line and the control is sized to its
/// content (`fixedSize`), so it can't wrap or squeeze; the header gives it
/// priority over the logo instead.
struct HomeModeToggle: View {
    static let onlineColor = Color(hex: 0x22C55E)
    static let offlineColor = Color(hex: 0xE53935)

    let mode: HomeConnectivityMode
    let onOnline: () -> Void
    let onOffline: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            segment(title: "Online", icon: "wifi", selected: !mode.isOffline, fill: Self.onlineColor, id: "homeModeOnline", action: onOnline)
            segment(title: "Offline", icon: "wifi.slash", selected: mode.isOffline, fill: Self.offlineColor, id: "homeModeOffline", action: onOffline)
        }
        .padding(3)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .overlay(Capsule().stroke(HomeTheme.stroke, lineWidth: 1))
        .fixedSize()
    }

    private func segment(title: String, icon: String, selected: Bool, fill: Color, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).accessibilityHidden(true)
                Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(selected ? Color.white : HomeTheme.textTertiary)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Capsule().fill(selected ? fill : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
