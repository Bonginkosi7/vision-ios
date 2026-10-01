import Foundation
import PDFKit
import ZIPFoundation

enum DocumentExtractionError: Error, LocalizedError {
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let message): return message
        }
    }
}

/// Real text extraction from an uploaded file. Throws on a genuinely
/// unreadable file — never returns fabricated text. Direct port of
/// DocumentExtractor.kt's interface.
protocol DocumentExtractor {
    func extract(fileURL: URL) throws -> String
}

struct TxtExtractor: DocumentExtractor {
    func extract(fileURL: URL) throws -> String {
        try String(contentsOf: fileURL, encoding: .utf8)
    }
}

/// Real PDF text extraction via PDFKit — Apple's first-party framework.
/// A genuine simplification over Android, which has no first-party
/// text-layer API (`PdfRenderer` only rasterizes pages to bitmaps) and
/// needs the third-party pdfbox-android library for this; iOS needs
/// nothing extra.
struct PdfExtractor: DocumentExtractor {
    func extract(fileURL: URL) throws -> String {
        guard let document = PDFDocument(url: fileURL) else {
            throw DocumentExtractionError.unreadable("This file doesn't look like a valid PDF.")
        }
        var text = ""
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex), let pageText = page.string {
                text += pageText
                text += "\n"
            }
        }
        return text
    }
}

/// A DOCX file is a zip archive; its real text lives in word/document.xml
/// as a sequence of `<w:p>` paragraphs containing `<w:t>` text runs. Reads
/// that real structure via ZIPFoundation (iOS has no first-party zip-
/// reading API, unlike Android's built-in `java.util.zip.ZipFile` — a
/// real, disclosed extra dependency for exactly that gap, same reasoning
/// as choosing GRDB over hand-rolled SQLite3 calls) plus Foundation's own
/// `XMLParser` (the direct Swift equivalent of Android's
/// `XmlPullParser`). Deliberately as targeted as DocxExtractor.kt: no
/// heading-style preservation, just the real full plain text.
final class DocxExtractor: DocumentExtractor {
    func extract(fileURL: URL) throws -> String {
        let archive = try Archive(url: fileURL, accessMode: .read)
        guard let entry = archive["word/document.xml"] else {
            throw DocumentExtractionError.unreadable("This file doesn't look like a valid DOCX document.")
        }

        var xmlData = Data()
        _ = try archive.extract(entry) { chunk in xmlData.append(chunk) }

        let parser = XMLParser(data: xmlData)
        let delegate = DocxXMLDelegate()
        parser.delegate = delegate
        guard parser.parse() else {
            throw DocumentExtractionError.unreadable("Couldn't read this DOCX document's contents.")
        }
        return delegate.paragraphs.joined(separator: "\n\n")
    }
}

private final class DocxXMLDelegate: NSObject, XMLParserDelegate {
    var paragraphs: [String] = []
    private var currentParagraph = ""
    private var inText = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch localName(elementName) {
        case "t": inText = true
        case "tab": currentParagraph += "\t"
        case "br", "cr": currentParagraph += "\n"
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText { currentParagraph += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = localName(elementName)
        if name == "t" { inText = false }
        if name == "p" {
            let trimmed = currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { paragraphs.append(trimmed) }
            currentParagraph = ""
        }
    }

    /// A DOCX element's real tag is namespace-prefixed ("w:t", "w:p") —
    /// XMLParser's default (shouldProcessNamespaces == false) hands that
    /// whole prefixed string to elementName, matching Android's own
    /// XmlPullParser default exactly, hence the same real need to strip
    /// the prefix here that DocxExtractor.kt's own localName() has.
    private func localName(_ name: String) -> String {
        guard let colonIndex = name.firstIndex(of: ":") else { return name }
        return String(name[name.index(after: colonIndex)...])
    }
}
