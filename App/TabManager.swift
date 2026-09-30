import Foundation
import WebKit
import VisionCore

/// Owns every real open tab and which one is active — the SwiftUI
/// equivalent of MainActivity.kt's `tabs`/`activeTabIndex` fields plus its
/// createTab/switchToTab/closeTab/navigateActiveTab functions. Index
/// arithmetic for closing a tab is delegated to VisionCore's TabIndexing,
/// the same pure logic already live-verified outside Xcode (see
/// vision-ios/README.md).
@MainActor
final class TabManager: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published private(set) var activeTabIndex: Int = -1

    var activeTab: BrowserTab? {
        guard tabs.indices.contains(activeTabIndex) else { return nil }
        return tabs[activeTabIndex]
    }

    @discardableResult
    func createTab(url: String?, switchToIt: Bool = true) -> BrowserTab {
        let webView = Self.makeWebView()
        let tab = BrowserTab(webView: webView)
        tabs.append(tab)
        if switchToIt {
            activeTabIndex = tabs.count - 1
        }
        if let url, let destinationURL = URL(string: url) {
            tab.isNewTab = false
            webView.load(URLRequest(url: destinationURL))
        }
        return tab
    }

    func switchToTab(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeTabIndex = index
    }

    /// Real navigation out of a tab's New Tab state — used by the address
    /// bar and the New Tab page's own bookmarks row.
    func navigateActiveTab(to destination: String) {
        guard let tab = activeTab, let destinationURL = URL(string: destination) else { return }
        tab.isNewTab = false
        tab.webView.load(URLRequest(url: destinationURL))
    }

    func closeTab(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        let countBeforeClose = tabs.count
        let activeBeforeClose = activeTabIndex
        tabs.remove(at: index)

        guard let newActiveIndex = TabIndexing.activeIndexAfterClose(
            tabCountBeforeClose: countBeforeClose,
            closedIndex: index,
            activeIndexBeforeClose: activeBeforeClose
        ) else {
            activeTabIndex = -1
            createTab(url: nil)
            return
        }
        activeTabIndex = newActiveIndex
    }

    private static func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        // WKWebView has JavaScript and DOM storage enabled by default,
        // unlike Android's WebView (which needs both explicitly turned on
        // in createTab()'s WebSettings block) — a real, disclosed platform
        // difference, not a missing step.
        return WKWebView(frame: .zero, configuration: configuration)
    }
}
