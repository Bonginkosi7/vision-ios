import Foundation

/// How two tabs share the screen in split view: side by side when there is room
/// (iPad, an iPhone held sideways), one above the other otherwise.
public enum SplitLayout {
    public enum Axis: Equatable, Sendable { case sideBySide, stacked }

    public static let defaultRatio = 0.5
    public static let minRatio = 0.25
    public static let maxRatio = 0.75
    /// Thickness of the divider between the panes, in points.
    public static let dividerThickness = 10.0
    /// Narrowest width that still gives each side-by-side pane a usable page.
    public static let sideBySideMinWidth = 700.0

    public static func axis(width: Double, height: Double = 0) -> Axis {
        width >= sideBySideMinWidth ? .sideBySide : .stacked
    }

    public static func clamp(_ ratio: Double) -> Double {
        guard ratio.isFinite else { return defaultRatio }
        return min(maxRatio, max(minRatio, ratio))
    }

    /// The size of the first (left or top) pane, given the container's size along the split axis.
    public static func firstPaneLength(extent: Double, ratio: Double) -> Double {
        let usable = max(0, extent - dividerThickness)
        return (usable * clamp(ratio)).rounded()
    }

    /// The ratio that puts the divider's centre at `position` (points from the container's start).
    public static func ratio(forDividerAt position: Double, extent: Double) -> Double {
        let usable = max(1, extent - dividerThickness)
        return clamp((position - dividerThickness / 2) / usable)
    }
}
