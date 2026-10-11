import XCTest
@testable import VisionCore

final class MemoryContextTests: XCTestCase {
    func testNoFactsMeansNoContext() {
        XCTAssertNil(MemoryContext.build(facts: []))
    }

    func testFactsBecomeABulletedBlock() {
        let text = MemoryContext.build(facts: ["I live in Cape Town", "I study biology"])!
        XCTAssertTrue(text.contains("- I live in Cape Town\n- I study biology"))
        XCTAssertTrue(text.contains("never inferred or guessed"))
    }

    func testOnlyTheNewestFactsAreKept() {
        let facts = (1...30).map { "fact \($0)" }
        let text = MemoryContext.build(facts: facts)!
        XCTAssertFalse(text.contains("- fact 10\n"))
        XCTAssertTrue(text.contains("- fact 30"))
        XCTAssertTrue(text.contains("- fact 11\n"))
    }
}
