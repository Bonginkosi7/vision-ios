import XCTest
@testable import VisionCore

final class FileKindTests: XCTestCase {
    func test_extensionDecidesTheKind_caseInsensitively() {
        XCTAssertEqual(FileKind.kind(filename: "Report.PDF", mimeType: nil), .pdf)
        XCTAssertEqual(FileKind.kind(filename: "photo.jpeg", mimeType: nil), .image)
        XCTAssertEqual(FileKind.kind(filename: "clip.mov", mimeType: nil), .video)
        XCTAssertEqual(FileKind.kind(filename: "song.mp3", mimeType: nil), .audio)
        XCTAssertEqual(FileKind.kind(filename: "bundle.zip", mimeType: nil), .archive)
        XCTAssertEqual(FileKind.kind(filename: "essay.docx", mimeType: nil), .document)
        XCTAssertEqual(FileKind.kind(filename: "budget.xlsx", mimeType: nil), .spreadsheet)
        XCTAssertEqual(FileKind.kind(filename: "talk.pptx", mimeType: nil), .presentation)
        XCTAssertEqual(FileKind.kind(filename: "notes.txt", mimeType: nil), .text)
    }

    func test_extensionBeatsAMisleadingMimeType() {
        XCTAssertEqual(FileKind.kind(filename: "report.pdf", mimeType: "application/octet-stream"), .pdf)
    }

    func test_fallsBackToMimeTypeWhenThereIsNoUsefulExtension() {
        XCTAssertEqual(FileKind.kind(filename: "download", mimeType: "application/pdf"), .pdf)
        XCTAssertEqual(FileKind.kind(filename: "download", mimeType: "image/png"), .image)
        XCTAssertEqual(FileKind.kind(filename: "download", mimeType: "video/mp4"), .video)
        XCTAssertEqual(FileKind.kind(filename: "download", mimeType: "text/html"), .text)
    }

    func test_unknownThingsAreOtherRatherThanGuessed() {
        XCTAssertEqual(FileKind.kind(filename: "mystery.xyz", mimeType: nil), .other)
        XCTAssertEqual(FileKind.kind(filename: "download", mimeType: "application/octet-stream"), .other)
    }
}
