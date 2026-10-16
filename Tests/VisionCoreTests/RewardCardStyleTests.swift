import XCTest
@testable import VisionCore

final class RewardCardStyleTests: XCTestCase {
    func testConnectivityUsesTheDesktopBlueToTeal() {
        let colors = RewardCardStyle.colors(forCategory: "connectivity")
        XCTAssertEqual(colors.start, 0x1E3A8A)
        XCTAssertEqual(colors.end, 0x0891B2)
    }

    func testCategoryLookupIgnoresCase() {
        XCTAssertEqual(RewardCardStyle.colors(forCategory: "Shopping"), RewardCardStyle.colors(forCategory: "shopping"))
    }

    func testUnknownCategoryFallsBackToLifestyle() {
        XCTAssertEqual(RewardCardStyle.colors(forCategory: "something-new"), RewardCardStyle.colors(forCategory: "lifestyle"))
    }

    func testEveryDesktopCategoryHasItsOwnColours() {
        let all = ["connectivity", "lifestyle", "entertainment", "education", "wellbeing", "shopping"].map { RewardCardStyle.colors(forCategory: $0).start }
        XCTAssertEqual(Set(all).count, 6)
    }
}
