import XCTest
@testable import VisionCore

/// Direct port of the real cases this mirrors from RewriteInstructions.kt
/// — every action has a real, distinct instruction, and every one ends
/// with the same real "reply with ONLY..." constraint the desktop/Android
/// prompts share verbatim.
final class RewriteInstructionsTests: XCTestCase {
    func test_everyAction_hasADistinctRealInstruction() {
        let instructions = RewriteAction.allCases.map(RewriteInstructions.forAction)
        XCTAssertEqual(Set(instructions).count, RewriteAction.allCases.count, "every action should have its own distinct instruction")
    }

    func test_everyInstruction_constrainsToOnlyTheResultText() {
        for action in RewriteAction.allCases {
            let instruction = RewriteInstructions.forAction(action)
            XCTAssertTrue(
                instruction.contains("Reply with ONLY"),
                "\(action.rawValue)'s instruction should constrain the model to just the result text"
            )
        }
    }

    func test_rewriteInstruction_mentionsKeepingMeaningAndTone() {
        XCTAssertTrue(RewriteInstructions.forAction(.rewrite).contains("meaning and tone"))
    }

    func test_summariseInstruction_mentionsKeyPoints() {
        XCTAssertTrue(RewriteInstructions.forAction(.summarise).contains("key points"))
    }
}
