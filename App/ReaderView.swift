import SwiftUI
import WebKit
import VisionCore

/// Reader View: the page's article on a clean, dark, comfortable page, with text-size and typeface controls.
/// Shown over the browser; Done returns to the page exactly as it was.
struct ReaderView: View {
    let article: ReaderArticle
    @Environment(\.dismiss) private var dismiss
    @AppStorage("reader_scale_percent") private var scalePercent = 100
    @AppStorage("reader_serif") private var serif = true

    private var prefs: ReaderPrefs { ReaderPrefs(scalePercent: scalePercent, serif: serif) }

    var body: some View {
        NavigationStack {
            ReaderWebView(html: ReaderCore.buildDocument(article: article, prefs: prefs), baseURL: URL(string: article.sourceURL))
                .ignoresSafeArea(edges: .bottom)
                .background(Color(white: 0.04))
                .navigationTitle("Reader View")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                            .accessibilityIdentifier("readerDoneButton")
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button { scalePercent = ReaderCore.clampScale(scalePercent - 10) } label: { Text("A−") }
                            .accessibilityLabel("Smaller text")
                            .accessibilityIdentifier("readerSmaller")
                        Button { scalePercent = ReaderCore.clampScale(scalePercent + 10) } label: { Text("A+") }
                            .accessibilityLabel("Larger text")
                            .accessibilityIdentifier("readerLarger")
                        Button { serif.toggle() } label: { Image(systemName: "textformat") }
                            .accessibilityLabel(serif ? "Use sans-serif" : "Use serif")
                            .accessibilityIdentifier("readerTypeface")
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

/// A web view with JavaScript off — the article is untrusted HTML from another site, so nothing in it may run.
/// Tapped links open in the system browser handoff of the sheet's owner via the normal navigation policy below.
private struct ReaderWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(white: 0.04, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(white: 0.04, alpha: 1)
        webView.navigationDelegate = context.coordinator
        webView.accessibilityIdentifier = "readerWebView"
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML = ""

        /// The article itself loads once; a tapped link leaves the reader and opens in Safari.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(navigationAction.navigationType == .other ? .allow : .cancel)
        }
    }
}
