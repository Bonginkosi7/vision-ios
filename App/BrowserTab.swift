import Foundation
import WebKit

/// One real browsing session: its own WKWebView instance (own back/forward
/// list, own WebKit render process), not a shared/faked tab. Direct port of
/// Tab.kt's structure — a class, not a struct, because each tab owns a
/// real, stateful WKWebView that must survive tab switches unchanged.
final class BrowserTab: Identifiable, ObservableObject {
    let id: UUID
    let webView: WKWebView

    @Published var title: String = ""
    @Published var url: String = ""
    /// True until this tab's first real navigation — while true, the
    /// shared New Tab view is shown instead of this (still blank) WKWebView.
    @Published var isNewTab: Bool = true

    init(id: UUID = UUID(), webView: WKWebView) {
        self.id = id
        self.webView = webView
    }
}
