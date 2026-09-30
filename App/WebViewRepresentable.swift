import SwiftUI
import WebKit

/// Bridges one real WKWebView into SwiftUI — WKWebView has no native
/// SwiftUI wrapper on any current iOS SDK, so this UIViewRepresentable is
/// the one place this app touches UIKit directly. Mirrors the real-time
/// progress/navigation callbacks MainActivity.kt's anonymous
/// WebViewClient/WebChromeClient provide on Android.
struct WebViewRepresentable: UIViewRepresentable {
    @ObservedObject var tab: BrowserTab

    func makeUIView(context: Context) -> WKWebView {
        tab.webView.navigationDelegate = context.coordinator
        tab.webView.uiDelegate = context.coordinator
        return tab.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // The WKWebView instance itself is the persistent state (owned by
        // BrowserTab, survives tab switches) — nothing to push down here.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let tab: BrowserTab

        init(tab: BrowserTab) {
            self.tab = tab
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            tab.url = webView.url?.absoluteString ?? tab.url
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab.title = webView.title ?? tab.title
            tab.url = webView.url?.absoluteString ?? tab.url
        }

        /// New-window requests (target="_blank" links, window.open) load in
        /// the same tab rather than silently doing nothing — WKWebView
        /// drops them entirely unless a UIDelegate handles this, unlike
        /// Android's WebView, which navigates in place by default.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
