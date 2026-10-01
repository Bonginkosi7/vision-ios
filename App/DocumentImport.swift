import Foundation
import VisionCore

enum DocumentImportError: Error, LocalizedError {
    case unsupportedType(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedType(let ext):
            return "Unsupported file type \".\(ext)\" — VISION currently supports PDF, DOCX, and TXT."
        }
    }
}

/// Copies a picked file into VISION's own app storage — direct port of
/// DocumentImport.kt's reasoning: a real local copy, not a reference to a
/// security-scoped URL that may not outlive this session (iOS's own real
/// equivalent of Android's content:// Uri permission grant — handled here
/// via startAccessingSecurityScopedResource(), a real platform
/// requirement Android's ContentResolver.openInputStream has no
/// equivalent for).
enum DocumentImport {
    private static let supportedExtensions: [String: StudyFileType] = ["pdf": .pdf, "docx": .docx, "txt": .txt]

    private static func studyDocumentsRoot() throws -> URL {
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("StudyDocuments", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func titleFromFilename(_ filename: String) -> String {
        let withoutExt = (filename as NSString).deletingPathExtension
        let cleaned = withoutExt.replacingOccurrences(of: "[_-]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? filename : cleaned
    }

    @discardableResult
    static func importFile(at sourceURL: URL, store: StudyDocumentStore) throws -> StudyDocument {
        let originalFilename = sourceURL.lastPathComponent
        let ext = sourceURL.pathExtension.lowercased()
        guard let fileType = supportedExtensions[ext] else {
            throw DocumentImportError.unsupportedType(ext)
        }

        let id = UUID().uuidString
        let dir = try studyDocumentsRoot().appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let destURL = dir.appendingPathComponent(originalFilename)

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }
        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        let attributes = try? FileManager.default.attributesOfItem(atPath: destURL.path)
        let sizeBytes = (attributes?[.size] as? NSNumber)?.int64Value ?? 0

        let document = StudyDocument(
            id: id, title: titleFromFilename(originalFilename), originalFilename: originalFilename,
            fileType: fileType, contentPath: destURL.path, sizeBytes: sizeBytes,
            status: .uploaded, processingError: nil, extractedText: nil, createdAt: Date()
        )
        return try store.insert(document)
    }

    private static func extractor(for fileType: StudyFileType) -> DocumentExtractor {
        switch fileType {
        case .pdf: return PdfExtractor()
        case .docx: return DocxExtractor()
        case .txt: return TxtExtractor()
        }
    }

    /// Real text extraction, run off the main thread by the caller — no
    /// AI call involved (that only happens when the user explicitly asks
    /// to extract topics). Honest failure at every stage, matching
    /// DocumentImport.kt's process(): an unreadable file or one with no
    /// real text layer (e.g. a scanned-image PDF) ends in .failed with a
    /// specific, real reason — never a silently-empty success.
    static func process(documentId: String, store: StudyDocumentStore) {
        guard let doc = try? store.get(id: documentId) else { return }
        try? store.updateProcessing(id: documentId, status: .processing, processingError: nil, extractedText: nil)

        let text: String
        do {
            text = try extractor(for: doc.fileType).extract(fileURL: URL(fileURLWithPath: doc.contentPath))
        } catch {
            try? store.updateProcessing(id: documentId, status: .failed, processingError: "Couldn't read this file: \(error.localizedDescription)", extractedText: nil)
            return
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let message = doc.fileType == .pdf
                ? "No real text could be extracted — this PDF may be a scanned image. OCR isn't supported yet."
                : "No real text could be extracted from this file."
            try? store.updateProcessing(id: documentId, status: .failed, processingError: message, extractedText: nil)
            return
        }

        try? store.updateProcessing(id: documentId, status: .processed, processingError: nil, extractedText: text)
    }

    static func remove(documentId: String, store: StudyDocumentStore) {
        guard let doc = try? store.get(id: documentId) else { return }
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: doc.contentPath).deletingLastPathComponent())
        try? store.remove(id: documentId)
    }
}
