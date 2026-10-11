import Foundation

/// Files the app saves (offline pages, study documents) are recorded by path. iOS may move the app's data
/// folder — after a reinstall, an update or a restore the part of the path before "Application Support"
/// changes — so a path saved earlier can stop pointing at the file even though the file is still there.
/// This finds the file again under the current Application Support folder.
enum StoredFilePath {
    private static let marker = "/Library/Application Support/"

    /// The file for a stored path: where it was recorded if it is still there, otherwise the same place
    /// inside the current Application Support folder.
    static func url(for storedPath: String) -> URL {
        let recorded = URL(fileURLWithPath: storedPath)
        if FileManager.default.fileExists(atPath: storedPath) { return recorded }
        guard let range = storedPath.range(of: marker, options: .backwards),
              let support = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        else { return recorded }
        let relative = String(storedPath[range.upperBound...])
        return support.appendingPathComponent(relative)
    }
}
