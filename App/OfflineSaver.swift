import Foundation
import WebKit

/// Captures the active tab's real current page as a real `.webarchive` file
/// via `WKWebView.createWebArchiveData(completionHandler:)` — Apple's own
/// native page-snapshot mechanism (iOS 14+), not a fabricated substitute.
/// Direct counterpart of Android's `WebView.saveWebArchive()` call in
/// MainActivity.kt's save-offline flow.
enum OfflineSaver {
    enum SaveError: Error {
        case noActivePage
        case archiveFailed(Error)
        case writeFailed(Error)
    }

    static func save(tab: BrowserTab, store: OfflineStore, completion: @escaping (Result<OfflineItem, SaveError>) -> Void) {
        guard !tab.isNewTab, !tab.url.isEmpty else {
            completion(.failure(.noActivePage))
            return
        }
        let url = tab.url
        let title = tab.title.isEmpty ? url : tab.title

        tab.webView.createWebArchiveData { result in
            switch result {
            case .failure(let error):
                completion(.failure(.archiveFailed(error)))
            case .success(let data):
                do {
                    let folder = try FileManager.default.url(
                        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
                    ).appendingPathComponent("OfflineLibrary", isDirectory: true)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

                    let filename = "\(UUID().uuidString).webarchive"
                    let fileURL = folder.appendingPathComponent(filename)
                    try data.write(to: fileURL)

                    let item = try store.add(
                        url: url,
                        title: title,
                        contentPath: fileURL.path,
                        sizeBytes: Int64(data.count)
                    )
                    DispatchQueue.main.async { completion(.success(item)) }
                } catch {
                    DispatchQueue.main.async { completion(.failure(.writeFailed(error))) }
                }
            }
        }
    }
}
