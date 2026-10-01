import XCTest
@testable import VisionCore

final class PaperReviewLogicTests: XCTestCase {
    func test_boundedText_trimsWhitespace() {
        XCTAssertEqual(PaperReviewLogic.boundedText("  hello world  "), "hello world")
    }

    func test_boundedText_boundsVeryLongText() {
        let longText = String(repeating: "x", count: 15_000)
        XCTAssertEqual(PaperReviewLogic.boundedText(longText).count, 12_000)
    }

    func test_parseReview_parsesRealIssuesAndDropsFullyEmptyOnes() {
        let json = """
        {"grammarIssues":[{"original":"teh","suggestion":"the","explanation":"typo"},{"original":"","suggestion":""}],"improvementSuggestions":["Be concise","","Vary sentence length"],"originalityNote":"The writing is clear but repeats transitional phrases."}
        """
        let review = PaperReviewLogic.parseReview(json)
        XCTAssertEqual(review?.grammarIssues.count, 1)
        XCTAssertEqual(review?.grammarIssues.first?.original, "teh")
        XCTAssertEqual(review?.improvementSuggestions.count, 2)
        XCTAssertTrue(review?.originalityNote.contains("repeats transitional") == true)
    }

    func test_parseReview_handlesGenuinelyEmptyIssuesAndSuggestions() {
        let json = """
        {"grammarIssues":[],"improvementSuggestions":[],"originalityNote":"Clean, well-structured writing with no issues found."}
        """
        let review = PaperReviewLogic.parseReview(json)
        XCTAssertEqual(review?.grammarIssues.count, 0)
        XCTAssertEqual(review?.improvementSuggestions.count, 0)
    }

    func test_parseReview_returnsNilForMalformedOrIncompleteJson() {
        XCTAssertNil(PaperReviewLogic.parseReview("not json"))
        XCTAssertNil(PaperReviewLogic.parseReview("{\"grammarIssues\":[],\"improvementSuggestions\":[]}"))
        XCTAssertNil(PaperReviewLogic.parseReview("{\"originalityNote\":\"\"}"))
    }

    func test_systemInstruction_neverClaimsPlagiarismDatabaseAccess() {
        XCTAssertTrue(PaperReviewLogic.systemInstruction.contains("NEVER claim to have checked"))
    }
}
