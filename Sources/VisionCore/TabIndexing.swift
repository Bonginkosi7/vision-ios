import Foundation

/// The pure index arithmetic behind closing a tab — direct port of
/// TabIndexing.kt (vision-android), pulled out of the tab-owning view model
/// so it's unit-testable without a live WKWebView/simulator, exactly the
/// same reasoning Android's own doc comment gives for why this exists as
/// its own file.
public enum TabIndexing {

    /// - Parameters:
    ///   - tabCountBeforeClose: how many tabs existed before this close
    ///   - closedIndex: the index of the tab being closed
    ///   - activeIndexBeforeClose: which index was active before this close
    /// - Returns: the correct active index afterward, or `nil` if no tabs
    ///   remain (the caller should open a fresh tab and reset to index 0
    ///   itself).
    public static func activeIndexAfterClose(
        tabCountBeforeClose: Int,
        closedIndex: Int,
        activeIndexBeforeClose: Int
    ) -> Int? {
        let remaining = tabCountBeforeClose - 1
        guard remaining > 0 else { return nil }
        if closedIndex == activeIndexBeforeClose {
            return min(closedIndex, remaining - 1)
        } else if closedIndex < activeIndexBeforeClose {
            return activeIndexBeforeClose - 1
        } else {
            return activeIndexBeforeClose
        }
    }
}
