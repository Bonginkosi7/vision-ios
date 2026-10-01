import XCTest
@testable import VisionCore

final class TutorLogicTests: XCTestCase {
    func test_systemInstruction_withNoDocument_isGeneralAndUngrounded() {
        let (instruction, grounded) = TutorLogic.systemInstruction(documentText: nil)
        XCTAssertFalse(grounded)
        XCTAssertTrue(instruction.contains("answer from your general knowledge"))
    }

    func test_systemInstruction_withBlankDocument_isGeneralAndUngrounded() {
        let (instruction, grounded) = TutorLogic.systemInstruction(documentText: "   ")
        XCTAssertFalse(grounded)
        XCTAssertTrue(instruction.contains("answer from your general knowledge"))
    }

    func test_systemInstruction_withRealDocument_isGroundedAndHonestAboutIt() {
        let (instruction, grounded) = TutorLogic.systemInstruction(documentText: "  Photosynthesis is the process...  ")
        XCTAssertTrue(grounded)
        XCTAssertTrue(instruction.contains("Photosynthesis is the process..."))
        XCTAssertTrue(instruction.contains("make clear your answer is based on the student's uploaded material"))
    }

    func test_systemInstruction_boundsVeryLongDocumentText() {
        let longText = String(repeating: "x", count: 9_000)
        let (instruction, _) = TutorLogic.systemInstruction(documentText: longText)
        XCTAssertTrue(instruction.contains(String(repeating: "x", count: TutorLogic.maxDocumentChars)))
        XCTAssertFalse(instruction.contains(String(repeating: "x", count: TutorLogic.maxDocumentChars + 1)))
    }

    func test_trimmedHistory_keepsOnlyTheMostRecentMessages() {
        let history = (0..<25).map { ChatMessage(role: $0 % 2 == 0 ? "user" : "assistant", content: "msg\($0)") }
        let trimmed = TutorLogic.trimmedHistory(history)
        XCTAssertEqual(trimmed.count, TutorLogic.maxHistoryMessages)
        XCTAssertEqual(trimmed.first?.content, "msg5")
        XCTAssertEqual(trimmed.last?.content, "msg24")
    }

    func test_trimmedHistory_passesThroughAShortHistoryUnchanged() {
        let history = [ChatMessage(role: "user", content: "hi")]
        XCTAssertEqual(TutorLogic.trimmedHistory(history).count, 1)
    }

    func test_unconfiguredAnswer_isHonestAndUngrounded() {
        XCTAssertFalse(TutorLogic.unconfiguredAnswer.groundedInDocument)
        XCTAssertNil(TutorLogic.unconfiguredAnswer.providerName)
        XCTAssertTrue(TutorLogic.unconfiguredAnswer.text.contains("Settings"))
    }
}
