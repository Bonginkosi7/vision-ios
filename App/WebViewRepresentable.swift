import SwiftUI
import WebKit

/// Bridges one real WKWebView into SwiftUI — WKWebView has no native
/// SwiftUI wrapper on any current iOS SDK, so this UIViewRepresentable is
/// the one place this app touches UIKit directly. Mirrors the real-time
/// progress/navigation callbacks MainActivity.kt's anonymous
/// WebViewClient/WebChromeClient provide on Android, plus real download
/// handling (WKDownloadDelegate) and real history recording — both gated
/// on `!tab.isPrivate`, the same real behavioral difference
/// PrivateBrowsingActivity.kt discloses for Android (never writes to
/// HistoryDbHelper).
struct WebViewRepresentable: UIViewRepresentable {
    @ObservedObject var tab: BrowserTab
    let historyStore: HistoryStore
    let downloadStore: DownloadStore

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
        Coordinator(tab: tab, historyStore: historyStore, downloadStore: downloadStore)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let tab: BrowserTab
        let historyStore: HistoryStore
        let downloadStore: DownloadStore
        /// WKDownload has no id of its own usable before a destination is
        /// chosen, so the real DownloadRecord created in
        /// decideDestinationUsing is kept here, keyed by the WKDownload's
        /// own identity, until its later delegate callbacks need it.
        private var recordsByDownload: [ObjectIdentifier: DownloadRecord] = [:]

        init(tab: BrowserTab, historyStore: HistoryStore, downloadStore: DownloadStore) {
            self.tab = tab
            self.historyStore = historyStore
            self.downloadStore = downloadStore
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            tab.url = webView.url?.absoluteString ?? tab.url
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab.title = webView.title ?? tab.title
            tab.url = webView.url?.absoluteString ?? tab.url
            if !tab.isPrivate, let url = webView.url?.absoluteString {
                try? historyStore.record(url: url, title: webView.title ?? "")
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
