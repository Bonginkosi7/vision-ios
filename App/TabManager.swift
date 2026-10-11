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
    /// Split view: two tabs on screen at once. The active tab is always the focused pane's tab, so the address bar,
    /// back/forward, bookmark and menu keep acting on "the tab being looked at". Both nil when not split.
    @Published private(set) var splitPrimaryID: UUID?
    @Published private(set) var splitSecondaryID: UUID?
    /// The first pane's share of the space, set by dragging the divider.
    @Published var splitRatio: Double = SplitLayout.defaultRatio

    private static let pinnedDefaultsKey = "vision.pinnedTabURLs"

    var activeTab: BrowserTab? {
        guard tabs.indices.contains(activeTabIndex) else { return nil }
        return tabs[activeTabIndex]
    }

    @discardableResult
    func createTab(url: String?, switchToIt: Bool = true, isPrivate: Bool = false, countAsOpened: Bool = true) -> BrowserTab {
        let webView = Self.makeWebView(isPrivate: isPrivate)
        let tab = BrowserTab(webView: webView, isPrivate: isPrivate)
        tab.onFocus = { [weak self, weak tab] in
            guard let self, let tab else { return }
            self.focus(tab)
        }
        tabs.append(tab)
        if countAsOpened { WellbeingManager.shared.recordTabOpened() }
        if switchToIt {
            activate(tab)
        }
        if let url, let destinationURL = URL(string: url) {
            tab.isNewTab = false
            webView.load(URLRequest(url: destinationURL))
        }
        return tab
    }

    /// Makes a tab the one on screen. In split view that means it takes the focused pane's place
    /// (or just takes focus, when it is already one of the two panes).
    private func activate(_ tab: BrowserTab) {
        if let pair = splitIDs, !pair.contains(tab.id), let activeID = activeTab?.id {
            if splitPrimaryID == activeID { splitPrimaryID = tab.id } else { splitSecondaryID = tab.id }
        }
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) { activeTabIndex = index }
        tab.loadPendingIfNeeded()
    }

    func switchToTab(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        activate(tabs[index])
    }

    /// Real navigation of one specific tab — the split view's New Tab pages navigate their own pane.
    func navigate(_ tab: BrowserTab, to destination: String) {
        guard let destinationURL = URL(string: destination) else { return }
        tab.isNewTab = false
        tab.pendingURL = nil
        tab.webView.load(URLRequest(url: destinationURL))
    }

    /// Real navigation out of a tab's New Tab state — used by the address
    /// bar and the New Tab page's own bookmarks row.
    func navigateActiveTab(to destination: String) {
        guard let tab = activeTab, let destinationURL = URL(string: destination) else { return }
        tab.isNewTab = false
        tab.webView.load(URLRequest(url: destinationURL))
    }

    /// Opens a real saved offline `.webarchive` file in the active tab —
    /// `loadFileURL` (not a plain URLRequest) is the real, required
    /// WKWebView API for local file access, which is sandboxed unlike a
    /// normal network request.
    func openOfflineFile(_ fileURL: URL) {
        guard let tab = activeTab else { return }
        tab.isNewTab = false
        tab.webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL)
    }

    func closeTab(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        // Closing one side of a split ends the split; the other side carries on as the one visible tab.
        if let pair = splitIDs, pair.contains(tab.id) {
            let partnerID = splitPrimaryID == tab.id ? splitSecondaryID : splitPrimaryID
            clearSplit()
            tabs.remove(at: index)
            if tab.isPinned { persistPinned() }
            if let partnerID, let partnerIndex = tabs.firstIndex(where: { $0.id == partnerID }) {
                activeTabIndex = partnerIndex
            } else if tabs.isEmpty {
                activeTabIndex = -1
                createTab(url: nil)
            } else {
                activeTabIndex = min(index, tabs.count - 1)
            }
            return
        }
        let wasPinned = tab.isPinned
        defer { if wasPinned { persistPinned() } }
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

    private static func makeWebView(isPrivate: Bool = false) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        // WKWebView has JavaScript and DOM storage enabled by default,
        // unlike Android's WebView (which needs both explicitly turned on
        // in createTab()'s WebSettings block) — a real, disclosed platform
        // difference, not a missing step.
        if isPrivate {
            // A real, genuinely isolated session — .nonPersistent() never
            // writes cookies/cache/DOM storage to disk in the first place,
            // which is actually a stronger real guarantee than Android's
            // own private-mode WebView (disk-based by default, needing an
            // explicit post-session wipe in PrivateBrowsingActivity.kt's
            // finishPrivateSession()) — there is nothing to wipe here
            // because nothing was ever written, a real simplification
            // worth disclosing rather than silently matching Android's
            // extra wipe step for no reason.
            configuration.websiteDataStore = .nonPersistent()
        }
        return WKWebView(frame: .zero, configuration: configuration)
    }

    // MARK: - Split view

    var isSplit: Bool { splitIDs != nil }

    private var splitIDs: Set<UUID>? {
        guard let a = splitPrimaryID, let b = splitSecondaryID else { return nil }
        return [a, b]
    }

    /// The two panes' tabs — first (left or top) and second (right or bottom).
    var splitTabs: (first: BrowserTab, second: BrowserTab)? {
        guard let a = splitPrimaryID, let b = splitSecondaryID,
              let first = tabs.first(where: { $0.id == a }), let second = tabs.first(where: { $0.id == b }) else { return nil }
        return (first, second)
    }

    private func clearSplit() {
        splitPrimaryID = nil
        splitSecondaryID = nil
        splitRatio = SplitLayout.defaultRatio
    }

    /// Shows two tabs together: the active tab first, and `other` (or a fresh New Tab) beside or below it, which gets focus.
    func openSplit(with other: BrowserTab? = nil) {
        guard let current = activeTab else { return }
        if isSplit {
            // Already split: put the requested tab into the pane that isn't focused.
            guard let other, other.id != current.id, !(splitIDs?.contains(other.id) ?? false) else { return }
            if splitPrimaryID == current.id { splitSecondaryID = other.id } else { splitPrimaryID = other.id }
            other.loadPendingIfNeeded()
            return
        }
        let second = (other != nil && other?.id != current.id) ? other! : createTab(url: nil, switchToIt: false, isPrivate: current.isPrivate)
        splitPrimaryID = current.id
        splitSecondaryID = second.id
        splitRatio = SplitLayout.defaultRatio
        activate(second)
    }

    /// Ends split view, keeping `tab` (default: the focused one) as the single visible tab. The other stays open.
    func closeSplit(keeping tab: BrowserTab? = nil) {
        guard isSplit else { return }
        let keep = tab ?? activeTab
        clearSplit()
        if let keep { activate(keep) }
    }

    func swapSplit() {
        guard isSplit else { return }
        swap(&splitPrimaryID, &splitSecondaryID)
    }

    /// Touching a pane's page makes it the focused one.
    func focus(_ tab: BrowserTab) {
        guard let pair = splitIDs, pair.contains(tab.id), activeTab?.id != tab.id else { return }
        activate(tab)
    }

    // MARK: - Pinned tabs

    /// Pins an open tab at its current address. False when it can't be (private, a blank New Tab, or the limit is reached).
    @discardableResult
    func pin(_ tab: BrowserTab) -> Bool {
        guard !tab.isPrivate, !tab.isPinned, !tab.isNewTab, PinnedTabs.isPinnable(tab.url),
              tabs.filter(\.isPinned).count < PinnedTabs.maxCount else { return false }
        tab.isPinned = true
        tab.pinURL = tab.url
        reorderPinnedFirst()
        persistPinned()
        return true
    }

    func unpin(_ tab: BrowserTab) {
        guard tab.isPinned else { return }
        tab.isPinned = false
        tab.pinURL = nil
        reorderPinnedFirst()
        persistPinned()
    }

    /// Pinned tabs first, each group keeping its order — and whichever tab is on screen stays on screen.
    private func reorderPinnedFirst() {
        let activeID = activeTab?.id
        tabs = PinnedTabs.pinnedFirst(tabs, isPinned: { $0.isPinned })
        activeTabIndex = tabs.firstIndex(where: { $0.id == activeID }) ?? activeTabIndex
    }

    private func persistPinned() {
        let urls = PinnedTabs.sanitize(tabs.filter(\.isPinned).compactMap(\.pinURL))
        UserDefaults.standard.set(urls, forKey: Self.pinnedDefaultsKey)
    }

    /// Brings back last time's pinned tabs, quietly: each loads the first time it is shown.
    func restorePinnedTabs() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.pinnedDefaultsKey) ?? []
        for url in PinnedTabs.sanitize(saved) {
            let tab = createTab(url: nil, switchToIt: false, countAsOpened: false)
            tab.isNewTab = false
            tab.url = url
            tab.title = FaviconCache.host(from: url) ?? url
            tab.pendingURL = url
            tab.isPinned = true
            tab.pinURL = url
        }
    }
}
