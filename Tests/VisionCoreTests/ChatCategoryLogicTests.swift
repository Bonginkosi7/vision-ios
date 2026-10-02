import XCTest
@testable import VisionCore

final class ChatCategoryLogicTests: XCTestCase {
    func test_classify_matchesEachRealCategory() {
        XCTAssertEqual(ChatCategoryLogic.classify("Can you explain photosynthesis to me?"), .learn)
        XCTAssertEqual(ChatCategoryLogic.classify("Please research the best laptops and compare them"), .research)
        XCTAssertEqual(ChatCategoryLogic.classify("Write me an email to my landlord"), .create)
        XCTAssertEqual(ChatCategoryLogic.classify("Help me plan my trip itinerary"), .plan)
        XCTAssertEqual(ChatCategoryLogic.classify("I need to prepare a report for my client meeting"), .work)
        XCTAssertEqual(ChatCategoryLogic.classify("hello there"), .general)
    }

    func test_classify_isCaseInsensitive() {
        XCTAssertEqual(ChatCategoryLogic.classify("EXPLAIN quantum physics"), .learn)
    }

    func test_classify_firstMatchWinsInOrder() {
        XCTAssertEqual(ChatCategoryLogic.classify("explain how to research this topic"), .learn)
    }

    func test_buildSystemInstruction_isHonestPerCategory() {
        XCTAssertTrue(ChatCategoryLogic.buildSystemInstruction(category: .learn).contains("explain it clearly"))
        XCTAssertTrue(ChatCategoryLogic.buildSystemInstruction(category: .research).contains("no open-ended web search"))
        XCTAssertTrue(ChatCategoryLogic.buildSystemInstruction(category: .general).contains("Never claim to have browsed the live web"))
    }

    func test_deriveSessionTitle_fromShortMessage_isUnchanged() {
        XCTAssertEqual(ChatSessionTitle.derive(fromFirstMessage: "Hello"), "Hello")
    }

    func test_deriveSessionTitle_collapsesWhitespace() {
        XCTAssertEqual(ChatSessionTitle.derive(fromFirstMessage: "Hello   world\n\nhow are you"), "Hello world how are you")
    }

    func test_deriveSessionTitle_truncatesLongMessages() {
        let title = ChatSessionTitle.derive(fromFirstMessage: String(repeating: "x", count: 100))
        XCTAssertTrue(title.hasSuffix("…"))
        XCTAssertEqual(title.count, 49)
    }

    func test_deriveSessionTitle_emptyMessageFallsBackToNewChat() {
        XCTAssertEqual(ChatSessionTitle.derive(fromFirstMessage: "   "), "New chat")
    }

    func test_trimmedHistory_keepsOnlyTheMostRecentMessages() {
        let history = (0..<25).map { ChatMessage(role: "user", content: "msg\($0)") }
        let trimmed = ChatCategoryLogic.trimmedHistory(history)
        XCTAssertEqual(trimmed.count, ChatCategoryLogic.maxHistoryMessages)
        XCTAssertEqual(trimmed.last?.content, "msg24")
    }
}
