import Foundation
import WebKit

/// One real browsing session: its own WKWebView instance (own back/forward
/// list, own WebKit render process), not a shared/faked tab. Direct port of
/// Tab.kt's structure — a class, not a struct, because each tab owns a
/// real, stateful WKWebView that must survive tab switches unchanged.
final class BrowserTab: Identifiable, ObservableObject {
    let id: UUID
    let webView: WKWebView
    /// True for a real private tab — its WKWebView was built with a
    /// `.nonPersistent()` data store (see TabManager.makeWebView), and
    /// WebViewRepresentable's coordinator skips history recording for it,
    /// the same real behavioral difference PrivateBrowsingActivity.kt
    /// discloses for Android (never writes to HistoryDbHelper).
    let isPrivate: Bool

    @Published var title: String = ""
    @Published var url: String = ""
    /// True until this tab's first real navigation — while true, the
    /// shared New Tab view is shown instead of this (still blank) WKWebView.
    @Published var isNewTab: Bool = true
    /// Real page-load progress — KVO-observed from the real WKWebView in
    /// WebViewRepresentable's Coordinator, the iOS counterpart of
    /// Android's `WebChromeClient.onProgressChanged` driving
    /// `activity_main.xml`'s own toolbar progress bar. Found missing
    /// entirely during a cross-source design sweep of the home browser.
    @Published var estimatedProgress: Double = 0
    @Published var isLoading: Bool = false
    /// Pinned tabs sit first in the tab list and come back at the next launch.
    @Published var isPinned: Bool = false
    /// True while this tab asks sites for their desktop pages ("Request Desktop Website").
    @Published var requestsDesktopSite: Bool = false
    /// The address this tab was pinned at — what gets reopened next launch.
    var pinURL: String?
    /// A pinned tab restored at launch isn't loaded until the first time it's shown, so a handful of pins don't all load at once.
    var pendingURL: String?
    /// Called when the user touches this tab's page — in split view that makes its pane the focused one.
    var onFocus: (() -> Void)?

    /// Loads the page a restored pinned tab was waiting to show.
    func loadPendingIfNeeded() {
        guard let pending = pendingURL, let url = URL(string: pending) else { return }
        pendingURL = nil
        webView.load(URLRequest(url: url))
    }

    init(id: UUID = UUID(), webView: WKWebView, isPrivate: Bool = false) {
        self.id = id
        self.webView = webView
        self.isPrivate = isPrivate
    }
}
