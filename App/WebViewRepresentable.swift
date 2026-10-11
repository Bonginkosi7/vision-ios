import SwiftUI
import WebKit
import VisionCore

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
        controller.removeScriptMessageHandler(forName: "sslBridge")
        controller.add(context.coordinator, name: "sslBridge")

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

        // In split view, touching a page makes its pane the focused one (the address bar and toolbar then act on it).
        // Observes only — it never cancels or delays the page's own touches.
        if !(tab.webView.gestureRecognizers ?? []).contains(where: { $0 is FocusTapRecognizer }) {
            tab.webView.addGestureRecognizer(FocusTapRecognizer(tab: tab))
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

    /// Tells the tab it was touched, without ever cancelling or delaying the page's own touches. It owns its own
    /// target (not the Coordinator, which is replaced when a tab moves between panes), and is added once per web view.
    final class FocusTapRecognizer: UITapGestureRecognizer, UIGestureRecognizerDelegate {
        private weak var tab: BrowserTab?

        init(tab: BrowserTab) {
            self.tab = tab
            super.init(target: nil, action: nil)
            addTarget(self, action: #selector(touched))
            cancelsTouchesInView = false
            delegate = self
        }

        @objc private func touched() { tab?.onFocus?() }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
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
        /// The certificate problem the warning page on screen is about, so "Proceed" knows what to accept.
        private var certificateFailure: CertificateFailure?
        private var showingCertificateWarning = false
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

        /// A page asks to use the camera and/or microphone. A remembered answer for this site is applied silently;
        /// otherwise the person is asked once, and the answer is remembered per site (never in a private tab).
        /// Managed in Settings → Site permissions. iOS then asks for the system permission itself if needed.
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void
        ) {
            let kinds: [SitePermissionKind]
            switch type {
            case .camera: kinds = [.camera]
            case .microphone: kinds = [.microphone]
            default: kinds = [.camera, .microphone]
            }
            guard let key = SitePermissionLogic.origin(scheme: origin.`protocol`, host: origin.host, port: origin.port) else {
                decisionHandler(.deny)
                return
            }
            let store = SitePermissionStore.shared
            let isPrivate = tab?.isPrivate ?? false
            switch SitePermissionLogic.resolve(kinds: kinds, remembered: { store.get(origin: key, kind: $0) }) {
            case .grant:
                decisionHandler(.grant)
            case .deny:
                decisionHandler(.deny)
            case .ask:
                let alert = UIAlertController(
                    title: SitePermissionLogic.promptText(host: origin.host, kinds: kinds),
                    message: isPrivate ? nil : "VISION remembers your answer for this site. You can change it in Settings → Site permissions.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Don't Allow", style: .cancel) { _ in
                    if !isPrivate { for kind in kinds { store.set(origin: key, kind: kind, granted: false) } }
                    decisionHandler(.deny)
                })
                alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in
                    if !isPrivate { for kind in kinds { store.set(origin: key, kind: kind, granted: true) } }
                    decisionHandler(.grant)
                })
                guard let presenter = Self.topViewController() else {
                    decisionHandler(.deny)
                    return
                }
                presenter.present(alert, animated: true)
            }
        }

        private static func topViewController() -> UIViewController? {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            return top
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            tab?.url = webView.url?.absoluteString ?? tab?.url ?? ""
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab?.title = webView.title ?? tab?.title ?? ""
            let urlString = webView.url?.absoluteString ?? tab?.url ?? ""
            tab?.url = urlString

            // The certificate warning is VISION's own page, not a site visit.
            if showingCertificateWarning {
                showingCertificateWarning = false
                return
            }

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

        // MARK: - Certificate errors

        /// A site whose certificate the system rejects is stopped (the default) and the warning page is shown.
        /// Only a certificate the user has just chosen to proceed past — same host, same certificate, this
        /// session — is accepted here.
        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let trust = challenge.protectionSpace.serverTrust,
                  let fingerprint = CertificateErrorPage.fingerprint(of: trust),
                  CertificateExceptionStore.shared.isAccepted(host: challenge.protectionSpace.host, fingerprint: fingerprint)
            else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            // The system only honours the user's choice for this certificate if its exceptions are set on the trust.
            _ = SecTrustEvaluateWithError(trust, nil)
            if let exceptions = SecTrustCopyExceptions(trust) { SecTrustSetExceptions(trust, exceptions) }
            completionHandler(.useCredential, URLCredential(trust: trust))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showCertificateWarningIfNeeded(webView, error: error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showCertificateWarningIfNeeded(webView, error: error)
        }

        private func showCertificateWarningIfNeeded(_ webView: WKWebView, error: Error) {
            guard let failure = CertificateFailure(error: error as NSError) else { return }
            certificateFailure = failure
            showingCertificateWarning = true
            tab?.isNewTab = false
            webView.loadHTMLString(CertificateErrorPage.html(for: failure), baseURL: failure.url)
        }

        private func handleCertificateBridge(_ action: String?) {
            guard let webView = tab?.webView else { return }
            switch action {
            case "goBack":
                certificateFailure = nil
                if webView.canGoBack {
                    webView.goBack()
                } else {
                    tab?.isNewTab = true
                    tab?.url = ""
                    webView.load(URLRequest(url: URL(string: "about:blank")!))
                }
            case "proceed":
                guard let failure = certificateFailure, let fingerprint = failure.fingerprint else { return }
                CertificateExceptionStore.shared.record(host: failure.host, fingerprint: fingerprint)
                certificateFailure = nil
                webView.load(URLRequest(url: failure.url))
            default:
                break
            }
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
            if message.name == "sslBridge" {
                handleCertificateBridge(message.body as? String)
                return
            }
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
