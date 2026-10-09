import SwiftUI
import VisionCore

/// Bridges the real data layer (RedemptionStore, RewardStore) to
/// RedeemView's existing plain-data interface — RedeemView was built
/// before this data layer existed (see its own doc comment: "takes
/// real-shaped data from its caller instead of reading a store directly")
/// and that interface is a genuinely clean seam, so this wraps it rather
/// than changing it. Loads on appear, then calls `RedemptionStore.sync()`
/// (real, on-demand — see that type's own doc comment on why this isn't a
/// true background job on iOS yet) and reloads once that settles, so a
/// redemption's status/the catalog itself can pick up a real remote
/// change made since the sheet last opened.
struct RedeemContainerView: View {
    let redemptionStore: RedemptionStore
    let rewardStore: RewardStore

    @State private var catalog: [RewardCatalogCacheEntry] = []
    @State private var history: [Redemption] = []
    @State private var balance: Int = 0

    var body: some View {
        RedeemView(
            availableBalance: balance,
            catalog: catalog.map(toCatalogItem),
            history: history.map(toRecord),
            isConfigured: FirebaseConfig.isConfigured(),
            onRedeem: { item, mobileNumber, network in
                guard let entry = catalog.first(where: { $0.id == item.id }) else {
                    return .rejected(reason: "This reward is no longer available.")
                }
                let outcome = (try? await redemptionStore.redeem(entry, mobileNumber: mobileNumber, network: network, rewardStore: rewardStore))
                    ?? .rejected(reason: "Something went wrong — try again.")
                await reload()
                switch outcome {
                case .submitted: return .submitted
                case .rejected(let reason): return .rejected(reason: reason)
                }
            }
        )
        .task {
            await reload()
            await redemptionStore.sync()
            await reload()
        }
    }

    private func reload() async {
        // RedemptionStore is @MainActor-isolated, and a View's own methods
        // aren't implicitly MainActor just because `body` is required to
        // be — so crossing into it needs `await` here even though
        // catalog()/history() are themselves plain synchronous functions.
        catalog = (try? await redemptionStore.catalog()) ?? []
        history = (try? await redemptionStore.history()) ?? []
        balance = (try? rewardStore.availableBalance()) ?? 0
    }

    private func toCatalogItem(_ entry: RewardCatalogCacheEntry) -> RedeemCatalogItem {
        let deviceCount = history.filter { $0.rewardID == entry.id && $0.status != .failed }.count
        let disabledReason: String?
        if let reason = RedemptionEligibility.checkEligibility(
            isActive: entry.isActive, status: entry.status, startDate: entry.startDate, endDate: entry.endDate,
            stock: entry.stock, redeemedCount: entry.redeemedCount, redemptionLimit: entry.redemptionLimit,
            dailyRedemptionLimit: entry.dailyRedemptionLimit, redeemedToday: entry.redeemedToday,
            userRedemptionLimit: entry.userRedemptionLimit, deviceRedemptionCount: deviceCount
        ) {
            disabledReason = reason
        } else if balance < entry.pointsCost {
            disabledReason = "Need \(entry.pointsCost - balance) more points"
        } else {
            disabledReason = nil
        }
        return RedeemCatalogItem(
            id: entry.id, title: entry.title, description: entry.entryDescription, pointsCost: entry.pointsCost,
            requiresMobileNumber: entry.requiresMobileNumber, requiresNetwork: entry.requiresNetwork,
            disabledReason: disabledReason
        )
    }

    private func toRecord(_ redemption: Redemption) -> RedemptionRecord {
        let status: RedemptionRecord.Status
        switch redemption.status {
        case .pending: status = .pending
        case .fulfilled: status = .fulfilled
        case .failed: status = .failed(reason: redemption.failureReason ?? "Unknown reason")
        }
        return RedemptionRecord(
            id: redemption.id, rewardTitle: redemption.rewardTitle, pointsCost: redemption.pointsCost,
            redeemedAt: redemption.redeemedAt, status: status, voucherCode: redemption.voucherCode
        )
    }
}
