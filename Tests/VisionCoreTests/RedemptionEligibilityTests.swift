import XCTest
@testable import VisionCore

/// Direct port of RedemptionEngineTest.kt's real checkEligibility()/
/// validate() cases.
final class RedemptionEligibilityTests: XCTestCase {
    private func baseEligible(
        isActive: Bool = true, status: String = "ACTIVE", startDate: Date? = nil, endDate: Date? = nil,
        stock: Int? = nil, redeemedCount: Int = 0, redemptionLimit: Int? = nil, dailyRedemptionLimit: Int? = nil,
        redeemedToday: Int = 0, userRedemptionLimit: Int? = nil, deviceRedemptionCount: Int = 0, now: Date = Date()
    ) -> String? {
        RedemptionEligibility.checkEligibility(
            isActive: isActive, status: status, startDate: startDate, endDate: endDate, stock: stock,
            redeemedCount: redeemedCount, redemptionLimit: redemptionLimit, dailyRedemptionLimit: dailyRedemptionLimit,
            redeemedToday: redeemedToday, userRedemptionLimit: userRedemptionLimit,
            deviceRedemptionCount: deviceRedemptionCount, now: now
        )
    }

    func test_anActiveRewardWithNoLimits_isEligible() {
        XCTAssertNil(baseEligible())
    }

    func test_anInactiveReward_isRejected() {
        XCTAssertEqual(baseEligible(isActive: false), "This reward isn't available right now.")
    }

    func test_archivedStatus_isRejected() {
        XCTAssertEqual(baseEligible(status: "ARCHIVED"), "This reward is no longer available.")
    }

    func test_pausedStatus_isRejected() {
        XCTAssertEqual(baseEligible(status: "PAUSED"), "This reward is temporarily paused.")
    }

    func test_comingSoonStatus_isRejected() {
        XCTAssertEqual(baseEligible(status: "COMING_SOON"), "This reward isn't available yet.")
    }

    func test_soldOutStatus_isRejected() {
        XCTAssertEqual(baseEligible(status: "SOLD_OUT"), "This reward is sold out.")
    }

    func test_beforeItsStartDate_isRejected() {
        let future = Date().addingTimeInterval(86400)
        XCTAssertEqual(baseEligible(startDate: future), "This reward isn't available yet.")
    }

    func test_afterItsEndDate_isRejected() {
        let past = Date().addingTimeInterval(-86400)
        XCTAssertEqual(baseEligible(endDate: past), "This reward is no longer available.")
    }

    func test_stockExhausted_isRejectedAsSoldOut() {
        XCTAssertEqual(baseEligible(stock: 5, redeemedCount: 5), "This reward is sold out.")
    }

    func test_redemptionLimitReached_isRejected() {
        XCTAssertEqual(baseEligible(redeemedCount: 100, redemptionLimit: 100), "This reward's redemption limit has been reached.")
    }

    func test_dailyRedemptionLimitReached_isRejected() {
        XCTAssertEqual(baseEligible(dailyRedemptionLimit: 10, redeemedToday: 10), "This reward's daily limit has been reached.")
    }

    func test_thisDeviceAlreadyAtItsOwnPerUserLimit_isRejected() {
        XCTAssertEqual(
            baseEligible(userRedemptionLimit: 1, deviceRedemptionCount: 1),
            "You've already redeemed this reward the maximum number of times."
        )
    }

    func test_anotherDeviceHavingRedeemedItDoesNotCountAgainstThisDevice() {
        // userRedemptionLimit is checked against deviceRedemptionCount, a
        // real per-device count the caller provides — never a global one.
        XCTAssertNil(baseEligible(userRedemptionLimit: 1, deviceRedemptionCount: 0))
    }

    // MARK: - validate()

    func test_noRequirements_needsNothing() {
        XCTAssertNil(RedemptionEligibility.validate(requiresMobileNumber: false, requiresNetwork: false, mobileNumber: nil, network: nil))
    }

    func test_requiresMobileNumber_rejectsAnInvalidOne() {
        XCTAssertEqual(
            RedemptionEligibility.validate(requiresMobileNumber: true, requiresNetwork: false, mobileNumber: "123", network: nil),
            "That doesn't look like a valid mobile number."
        )
    }

    func test_requiresMobileNumber_acceptsARealOne() {
        XCTAssertNil(RedemptionEligibility.validate(requiresMobileNumber: true, requiresNetwork: false, mobileNumber: "0821234567", network: nil))
    }

    func test_requiresNetwork_rejectsAMissingOne() {
        XCTAssertEqual(
            RedemptionEligibility.validate(requiresMobileNumber: false, requiresNetwork: true, mobileNumber: nil, network: nil),
            "Please select a network."
        )
    }

    func test_requiresNetwork_acceptsARealOne() {
        XCTAssertNil(RedemptionEligibility.validate(requiresMobileNumber: false, requiresNetwork: true, mobileNumber: nil, network: "MTN"))
    }
}
