import Foundation

/// Pure port of RedemptionEngine.kt's checkEligibility()/validate() — the
/// real gate a redemption attempt passes through before any network/DB
/// call happens, split out exactly like RewardEligibility.swift already is
/// for the earning side, so both are directly unit-testable with no store
/// or GRDB dependency.
///
/// Takes flat primitives rather than a shared catalog-entry struct
/// (unlike the Kotlin original, which takes a whole `CachedRewardCatalogEntry`)
/// — VisionCore's own real constraint is zero GRDB/SwiftUI dependencies,
/// and the real catalog-entry record type needs GRDB conformance, so it
/// lives in the App target instead (RedemptionStore.swift). The caller
/// there destructures its own record into these same real fields.
public enum RedemptionEligibility {
    /// Mirrors desktop's real checkEligibility() (status/dates/stock/
    /// redemptionLimit), with the same one deliberate divergence Android's
    /// own port already made: userRedemptionLimit is checked against THIS
    /// DEVICE's own real local redemption count, not a global live count
    /// (desktop's single-user app has no per-user column at all; a literal
    /// port would mean nothing once real multiple installs exist).
    /// stock/redemptionLimit still check against the last-synced catalog
    /// snapshot's real counts — not perfectly atomic across devices, the
    /// same disclosed limitation Android's own doc comment names.
    public static func checkEligibility(
        isActive: Bool,
        status: String,
        startDate: Date?,
        endDate: Date?,
        stock: Int?,
        redeemedCount: Int,
        redemptionLimit: Int?,
        dailyRedemptionLimit: Int?,
        redeemedToday: Int,
        userRedemptionLimit: Int?,
        deviceRedemptionCount: Int,
        now: Date = Date()
    ) -> String? {
        if !isActive { return "This reward isn't available right now." }
        switch status {
        case "ARCHIVED", "EXPIRED": return "This reward is no longer available."
        case "PAUSED": return "This reward is temporarily paused."
        case "COMING_SOON": return "This reward isn't available yet."
        case "SOLD_OUT": return "This reward is sold out."
        default: break
        }
        if let startDate, now < startDate { return "This reward isn't available yet." }
        if let endDate, now > endDate { return "This reward is no longer available." }
        if let stock, redeemedCount >= stock { return "This reward is sold out." }
        if let redemptionLimit, redeemedCount >= redemptionLimit { return "This reward's redemption limit has been reached." }
        if let dailyRedemptionLimit, redeemedToday >= dailyRedemptionLimit { return "This reward's daily limit has been reached." }
        if let userRedemptionLimit, deviceRedemptionCount >= userRedemptionLimit {
            return "You've already redeemed this reward the maximum number of times."
        }
        return nil
    }

    /// Real SA mobile number/network validation — mirrors desktop's
    /// fulfillment.validate(), applies regardless of which fulfillment
    /// type ultimately processes the reward.
    public static func validate(requiresMobileNumber: Bool, requiresNetwork: Bool, mobileNumber: String?, network: String?) -> String? {
        if requiresMobileNumber {
            guard let mobileNumber, !mobileNumber.isEmpty, MobileValidation.isValidSouthAfricanMobileNumber(mobileNumber) else {
                return "That doesn't look like a valid mobile number."
            }
        }
        if requiresNetwork, network?.isEmpty ?? true {
            return "Please select a network."
        }
        return nil
    }
}
