import SwiftUI
import WebKit

/// Bridges one real WKWebView into SwiftUI — WKWebView has no native
/// SwiftUI wrapper on any current iOS SDK, so this UIViewRepresentable is
/// the one place this app touches UIKit directly. Mirrors the real-time
/// progress/navigation callbacks MainActivity.kt's anonymous
/// WebViewClient/WebChromeClient provide on Android, plus real history
/// recording, real `WKDownloadDelegate` handling, real wellbeing
/// site-visit tracking, and real Focus Mode blocking (gated on
/// `!tab.isPrivate` where that applies — Focus Mode blocking itself
/// applies to every tab, matching Android's own `shouldOverrideUrlLoading`
/// check, which isn't gated on private mode either).
struct WebViewRepresentable: UIViewRepresentable {
    @ObservedObject var tab: BrowserTab
    let historyStore: HistoryStore
    let downloadStore: DownloadStore
    let wellbeingStore: WellbeingStore

    func makeUIView(context: Context) -> WKWebView {
        tab.webView.navigationDelegate = context.coordinator
        tab.webView.uiDelegate = context.coordinator

        // Defensive remove-then-add: if this representable's underlying
        // UIView gets torn down and recreated for the same real
        // tab.webView (switching tabs away and back can do this),
        // `makeUIView` can run again for the same WKWebView — adding a
        // script message handler with a name that's already registered a
        // second time is a real, avoidable bug, not a theoretical one.
        let controller = tab.webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "focusBridge")
        controller.add(context.coordinator, name: "focusBridge")

        // Swipe right from the left edge = back, swipe left from the right
        // edge = forward, with WebKit's own interactive page snapshot.
        tab.webView.allowsBackForwardNavigationGestures = true

        // Pull down at the top of a page to reload it, the standard iOS
        // browser gesture.
        if tab.webView.scrollView.refreshControl == nil {
            let refresh = UIRefreshControl()
            refresh.addTarget(context.coordinator, action: #selector(Coordinator.pullToRefresh(_:)), for: .valueChanged)
            tab.webView.scrollView.refreshControl = refresh
        }

        return tab.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // The WKWebView instance itself is the persistent state (owned by
        // BrowserTab, survives tab switches) — nothing to push down here.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab, historyStore: historyStore, downloadStore: downloadStore, wellbeingStore: wellbeingStore)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        // weak, deliberately: WKUserContentController.add(_:name:) (called
        // in makeUIView above) makes tab.webView's own configuration hold a
        // strong reference to this Coordinator. If Coordinator held `tab`
        // strongly too, that would be a genuine retain cycle (tab ->
        // webView -> userContentController -> Coordinator -> tab) that
        // leaks every tab forever once Focus Mode's bridge is registered —
        // not a hypothetical, a real consequence of wiring this up.
        weak var tab: BrowserTab?
        let historyStore: HistoryStore
        let downloadStore: DownloadStore
        let wellbeingStore: WellbeingStore
        private var recordsByDownload: [ObjectIdentifier: DownloadRecord] = [:]
        /// Real page-load progress/loading-state observation — the iOS
        /// counterpart of Android's `WebChromeClient.onProgressChanged`.
        /// Kept alive for this Coordinator's own lifetime (itself retained
        /// by the WKWebView's userContentController, see the class doc
        /// comment above on why `tab` is held weakly here).
        private var observations: [NSKeyValueObservation] = []

        init(tab: BrowserTab, historyStore: HistoryStore, downloadStore: DownloadStore, wellbeingStore: WellbeingStore) {
            self.tab = tab
            self.historyStore = historyStore
            self.downloadStore = downloadStore
            self.wellbeingStore = wellbeingStore
            super.init()
            observations = [
                tab.webView.observe(\.estimatedProgress, options: [.new]) { [weak tab] webView, _ in
                    tab?.estimatedProgress = webView.estimatedProgress
                },
                tab.webView.observe(\.isLoading, options: [.new]) { [weak tab] webView, _ in
                    tab?.isLoading = webView.isLoading
                    // Whatever ended the load (finish, failure, cancel),
                    // the pull-to-refresh spinner must stop with it.
                    if !webView.isLoading { webView.scrollView.refreshControl?.endRefreshing() }
                },
                // A back/forward swipe changes these without any toolbar
                // tap — nudge the tab so the toolbar re-reads enabled state.
                tab.webView.observe(\.canGoBack, options: [.new]) { [weak tab] _, _ in
                    tab?.objectWillChange.send()
                },
                tab.webView.observe(\.canGoForward, options: [.new]) { [weak tab] _, _ in
                    tab?.objectWillChange.send()
                },
            ]
        }

        @objc func pullToRefresh(_ sender: UIRefreshControl) {
            guard let webView = tab?.webView else { sender.endRefreshing(); return }
            // A page that never loaded (error/blank) has no URL to reload.
            if webView.url != nil { webView.reload() } else { sender.endRefreshing() }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            tab?.url = webView.url?.absoluteString ?? tab?.url ?? ""
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab?.title = webView.title ?? tab?.title ?? ""
            let urlString = webView.url?.absoluteString ?? tab?.url ?? ""
            tab?.url = urlString

            // Real page loads only — never the local blocked-page HTML
            // (loaded via loadHTMLString, so webView.url is nil/about:blank,
            // not a real http(s) URL) or an offline file:// archive, neither
            // of which is a real "site visit" or history entry.
            guard urlString.hasPrefix("http://") || urlString.hasPrefix("https://") else { return }
            if tab?.isPrivate != true {
                try? historyStore.record(url: urlString, title: webView.title ?? "")
                // Saves the page's own declared icon for History/Bookmarks/
                // Downloads/Offline Library. Never for private tabs.
                FaviconCache.captureIcon(from: webView)
            }
            if let host = URL(string: urlString)?.host {
                try? wellbeingStore.recordSiteVisit(hostname: host)
            }
        }

        /// Real Focus Mode blocking — direct port of MainActivity.kt's
        /// `shouldOverrideUrlLoading` check. Cancels the real navigation
        /// and shows FocusBlockedPage's local HTML instead, matching
        /// Android's loadDataWithBaseURL substitution.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if
                let url = navigationAction.request.url?.absoluteString,
                let blockedDomain = FocusManager.shared.matchBlockedDomain(url: url)
            {
                FocusManager.shared.recordBlockedAttempt()
                decisionHandler(.cancel)
                if let session = FocusManager.shared.activeSession {
                    webView.loadHTMLString(FocusBlockedPage.html(domain: blockedDomain, endsAt: session.endsAt), baseURL: nil)
                }
                return
            }
            decisionHandler(.allow)
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

        /// The blocked page's "End session" button — direct equivalent of
        /// FocusJsBridge.kt's @JavascriptInterface endSession(), reached
        /// here via `window.webkit.messageHandlers.focusBridge.postMessage(...)`
        /// instead of Android's addJavascriptInterface.
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "focusBridge", (message.body as? String) == "endSession" else { return }
            FocusManager.shared.stopSession()
            tab?.webView.evaluateJavaScript("""
                clearInterval(window.__tickInterval);
                document.getElementById('subtext').textContent = 'Your focus session has ended — this page is just stale.';
                document.getElementById('countdown').textContent = '';
                document.querySelector('button').style.display = 'none';
                """)
        }

        // MARK: - Real downloads (WKDownload — iOS's actual download
        // mechanism, no system DownloadManager service to hand off to the
        // way Android does; this app owns the whole transfer itself).

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            let httpResponse = navigationResponse.response as? HTTPURLResponse
            let isAttachment = httpResponse?
                .value(forHTTPHeaderField: "Content-Disposition")?
                .lowercased()
                .contains("attachment") ?? false
            if isAttachment || !navigationResponse.canShowMIMEType {
                decisionHandler(.download)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }
    }
}

extension WebViewRepresentable.Coordinator: WKDownloadDelegate {
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        do {
            let downloadsFolder = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            ).appendingPathComponent("Downloads", isDirectory: true)
            try FileManager.default.createDirectory(at: downloadsFolder, withIntermediateDirectories: true)

            // A real download to the same filename twice shouldn't silently
            // overwrite the earlier file — number it instead, same
            // real-not-fabricated-collision-handling spirit as everything
            // else in this app.
            var destination = downloadsFolder.appendingPathComponent(suggestedFilename)
            var counter = 1
            let base = (suggestedFilename as NSString).deletingPathExtension
            let ext = (suggestedFilename as NSString).pathExtension
            while FileManager.default.fileExists(atPath: destination.path) {
                let numbered = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
                destination = downloadsFolder.appendingPathComponent(numbered)
                counter += 1
            }

            let record = try downloadStore.create(
                url: response.url?.absoluteString ?? "",
                filename: destination.lastPathComponent,
                mimeType: response.mimeType,
                totalBytes: response.expectedContentLength > 0 ? response.expectedContentLength : 0
            )
            recordsByDownload[ObjectIdentifier(download)] = record
            completionHandler(destination)
        } catch {
            completionHandler(nil)
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let record = recordsByDownload[ObjectIdentifier(download)] else { return }
        let attributes = try? FileManager.default.attributesOfItem(atPath: destinationPath(for: record))
        let actualSize = (attributes?[.size] as? NSNumber)?.int64Value ?? record.totalBytes
        try? downloadStore.updateProgress(id: record.id, receivedBytes: actualSize, state: .completed)
        recordsByDownload.removeValue(forKey: ObjectIdentifier(download))
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let record = recordsByDownload[ObjectIdentifier(download)] else { return }
        try? downloadStore.updateProgress(id: record.id, receivedBytes: record.receivedBytes, state: .failed)
        recordsByDownload.removeValue(forKey: ObjectIdentifier(download))
    }

    private func destinationPath(for record: DownloadRecord) -> String {
        let downloadsFolder = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ).appendingPathComponent("Downloads", isDirectory: true)) ?? URL(fileURLWithPath: "/dev/null")
        return downloadsFolder.appendingPathComponent(record.filename).path
    }
}
