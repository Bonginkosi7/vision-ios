import Foundation

/// What kind of file a download is, decided from its real filename extension
/// first (most reliable) and its MIME type second. Drives the one icon each
/// Downloads row shows, so the icon says something true about the file.
public enum FileKind: Equatable {
    case pdf, image, video, audio, archive, document, spreadsheet, presentation, text, other

    public static func kind(filename: String, mimeType: String?) -> FileKind {
        let ext = (filename as NSString).pathExtension.lowercased()
        if let byExtension = byExtension[ext] { return byExtension }

        let mime = (mimeType ?? "").lowercased()
        if mime == "application/pdf" { return .pdf }
        if mime.hasPrefix("image/") { return .image }
        if mime.hasPrefix("video/") { return .video }
        if mime.hasPrefix("audio/") { return .audio }
        if mime == "application/zip" || mime.contains("compressed") || mime.contains("x-tar") { return .archive }
        if mime.hasPrefix("text/") { return .text }
        return .other
    }

    private static let byExtension: [String: FileKind] = {
        var map: [String: FileKind] = [:]
        func add(_ kind: FileKind, _ extensions: [String]) { extensions.forEach { map[$0] = kind } }
        add(.pdf, ["pdf"])
        add(.image, ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff", "svg"])
        add(.video, ["mp4", "mov", "m4v", "avi", "mkv", "webm"])
        add(.audio, ["mp3", "m4a", "wav", "aac", "flac", "ogg"])
        add(.archive, ["zip", "rar", "7z", "tar", "gz", "tgz"])
        add(.document, ["doc", "docx", "pages", "rtf", "odt", "epub"])
        add(.spreadsheet, ["xls", "xlsx", "numbers", "csv", "ods"])
        add(.presentation, ["ppt", "pptx", "key", "odp"])
        add(.text, ["txt", "md", "json", "xml", "log"])
        return map
    }()
}
