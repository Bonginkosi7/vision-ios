import XCTest
@testable import VisionCore

final class SplashTimingTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testTheSplashStaysUpForTheRestOfItsMinimumTime() {
        XCTAssertEqual(SplashTiming.remaining(processStart: start, now: start.addingTimeInterval(0.4)), 2.6, accuracy: 0.0001)
        XCTAssertEqual(SplashTiming.remaining(processStart: start, now: start), 3, accuracy: 0.0001)
    }

    func testNothingRemainsOnceTheMinimumHasPassed() {
        XCTAssertEqual(SplashTiming.remaining(processStart: start, now: start.addingTimeInterval(3)), 0)
        XCTAssertEqual(SplashTiming.remaining(processStart: start, now: start.addingTimeInterval(10)), 0)
    }

    func testTheMinimumIsThreeSeconds() {
        XCTAssertEqual(SplashTiming.minimumSeconds, 3)
    }
}
