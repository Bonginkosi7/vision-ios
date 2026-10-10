import Foundation

/// Where the on-device model lives and what it is. One file, one model:
/// Qwen2.5-0.5B-Instruct (Apache-2.0, ungated) in 8-bit GGUF — the same
/// model family and size class the Android app ships.
enum LocalModelFile {
    static let displayName = "Qwen2.5 0.5B Instruct"
    static let downloadURL = URL(string: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q8_0.gguf")!
    /// Exact byte size reported by the server — a finished file of any other
    /// size is treated as corrupt and thrown away, never loaded.
    static let expectedBytes: Int64 = 675_710_816

    static var url: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("local-models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("qwen2.5-0.5b-instruct-q8_0.gguf")
    }

    static var isDownloaded: Bool {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? nil
        return size == expectedBytes
    }

    static var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: expectedBytes, countStyle: .file)
    }
}

/// Downloads, tracks, and removes the on-device model. Works on Wi-Fi or
/// mobile data — the user decides, after being told the size and (when
/// relevant) that mobile data will be used.
@MainActor
final class LocalModelManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = LocalModelManager()

    enum State: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case failed(String)
    }

    @Published private(set) var state: State = LocalModelFile.isDownloaded ? .ready : .notDownloaded

    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var resumeData: Data?

    private override init() { super.init() }

    var isBusy: Bool { if case .downloading = state { return true } else { return false } }

    func start() {
        guard !isBusy, !LocalModelFile.isDownloaded else { return }
        let free = (try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage ?? Int64.max
        guard free > LocalModelFile.expectedBytes + 300_000_000 else {
            state = .failed("Not enough free storage. Free up about \(ByteCountFormatter.string(fromByteCount: LocalModelFile.expectedBytes + 300_000_000, countStyle: .file)) and try again.")
            return
        }
        let configuration = URLSessionConfiguration.default
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        self.session = session
        let task = resumeData.map { session.downloadTask(withResumeData: $0) } ?? session.downloadTask(with: LocalModelFile.downloadURL)
        resumeData = nil
        self.task = task
        state = .downloading(progress: 0)
        task.resume()
    }

    func cancel() {
        task?.cancel(byProducingResumeData: { data in
            Task { @MainActor in LocalModelManager.shared.resumeData = data }
        })
        task = nil
        session?.finishTasksAndInvalidate()
        session = nil
        state = LocalModelFile.isDownloaded ? .ready : .notDownloaded
    }

    func remove() {
        cancel()
        Task { await LocalLLM.shared.unload() }
        try? FileManager.default.removeItem(at: LocalModelFile.url)
        state = .notDownloaded
    }

    // MARK: URLSessionDownloadDelegate (delegate queue is main)

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : LocalModelFile.expectedBytes
        let fraction = min(1, Double(totalBytesWritten) / Double(total))
        Task { @MainActor in
            let manager = LocalModelManager.shared
            if case .downloading = manager.state { manager.state = .downloading(progress: fraction) }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The temp file is deleted when this method returns — move it now.
        let destination = LocalModelFile.url
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 200
        var failure: String?
        do {
            guard (200...299).contains(status) else { throw URLError(.badServerResponse) }
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            let size = (try FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? 0
            if size != LocalModelFile.expectedBytes {
                try? FileManager.default.removeItem(at: destination)
                failure = "The download was incomplete. Please try again."
            } else {
                var values = URLResourceValues()
                values.isExcludedFromBackup = true // re-downloadable, keep it out of iCloud backups
                var mutableURL = destination
                try? mutableURL.setResourceValues(values)
            }
        } catch {
            failure = "The download failed (\(error.localizedDescription)). Please try again."
        }
        let finalFailure = failure
        Task { @MainActor in
            LocalModelManager.shared.task = nil
            LocalModelManager.shared.state = finalFailure.map { .failed($0) } ?? .ready
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let nsError = error as NSError
        guard nsError.code != NSURLErrorCancelled else { return }
        let data = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        let message = "The download stopped (\(error.localizedDescription)). Tap Download to resume."
        Task { @MainActor in
            LocalModelManager.shared.resumeData = data
            LocalModelManager.shared.task = nil
            LocalModelManager.shared.state = .failed(message)
        }
    }
}
