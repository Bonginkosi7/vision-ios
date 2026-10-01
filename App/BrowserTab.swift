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

    init(id: UUID = UUID(), webView: WKWebView, isPrivate: Bool = false) {
        self.id = id
        self.webView = webView
        self.isPrivate = isPrivate
    }
}
