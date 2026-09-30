import XCTest
@testable import VisionCore

/// Direct port of TabIndexingTest.kt's real cases (vision-android) —
/// regression coverage for a real bug caught during Android's own
/// development: closing a tab positioned before the active one left the
/// active index pointing one tab off from what was actually on screen,
/// because every index after the removed tab shifts down by one.
final class TabIndexingTests: XCTestCase {

    func test_closingATabBeforeTheActiveOne_shiftsTheActiveIndexDownByOne() {
        // [A, B, C], active = C (index 2). Close A (index 0).
        let result = TabIndexing.activeIndexAfterClose(tabCountBeforeClose: 3, closedIndex: 0, activeIndexBeforeClose: 2)
        XCTAssertEqual(result, 1) // C is now at index 1
    }

    func test_closingATabAfterTheActiveOne_leavesTheActiveIndexUnchanged() {
        // [A, B, C], active = A (index 0). Close C (index 2).
        let result = TabIndexing.activeIndexAfterClose(tabCountBeforeClose: 3, closedIndex: 2, activeIndexBeforeClose: 0)
        XCTAssertEqual(result, 0)
    }

    func test_closingTheActiveMiddleTab_selectsTheTabThatShiftedIntoItsPlace() {
        // [A, B, C], active = B (index 1). Close B.
        let result = TabIndexing.activeIndexAfterClose(tabCountBeforeClose: 3, closedIndex: 1, activeIndexBeforeClose: 1)
        XCTAssertEqual(result, 1) // C shifted down into index 1
    }

    func test_closingTheActiveLastTab_fallsBackToTheNewLastTab() {
        // [A, B, C], active = C (index 2). Close C.
        let result = TabIndexing.activeIndexAfterClose(tabCountBeforeClose: 3, closedIndex: 2, activeIndexBeforeClose: 2)
        XCTAssertEqual(result, 1) // B is now the last tab
    }

    func test_closingTheOnlyTab_returnsNilSoTheCallerOpensAFreshOne() {
        let result = TabIndexing.activeIndexAfterClose(tabCountBeforeClose: 1, closedIndex: 0, activeIndexBeforeClose: 0)
        XCTAssertNil(result)
    }

    func test_closingABackgroundTabTwoPositionsBeforeTheActiveOne_shiftsItDownByOneNotTwo() {
        // [A, B, C, D], active = D (index 3). Close B (index 1).
        let result = TabIndexing.activeIndexAfterClose(tabCountBeforeClose: 4, closedIndex: 1, activeIndexBeforeClose: 3)
        XCTAssertEqual(result, 2) // D is now at index 2
    }
}
