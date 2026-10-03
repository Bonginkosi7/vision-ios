import SwiftUI

/// Local UI-layer mirror of the fields RedeemActivity.kt's real catalog
/// entry (CachedRewardCatalogEntry, RewardCatalogDbHelper.kt) actually
/// renders. This type deliberately lives here in the UI layer rather than
/// in VisionCore/RewardStore: iOS has no catalog/redemption data layer yet
/// (no port of RewardCatalogDbHelper, RedemptionDbHelper, RedemptionEngine,
/// or RewardCatalogRemote — see RewardStore.swift's own note that Redeem
/// isn't ported), so this view takes real-shaped data from its caller
/// instead of reading a store directly, the way RewardsView reads
/// RewardStore directly only because that store already exists. Whoever
/// wires this up for real should either move this type (and
/// RedemptionRecord below) into VisionCore alongside a real RedemptionEngine
/// port, or map their own model onto it.
struct RedeemCatalogItem: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let pointsCost: Int
    let requiresMobileNumber: Bool
    let requiresNetwork: Bool
    /// Non-nil mirrors RedeemActivity.kt's disabled-button text — either a
    /// real eligibility error (RedemptionEngine.checkEligibility) or the
    /// real "Need N more points" shortfall. nil means redeemable right now.
    let disabledReason: String?
}

/// Local mirror of RedemptionDbHelper.kt's real redemption row — only the
/// fields "My Redemptions" actually shows.
struct RedemptionRecord: Identifiable, Equatable {
    enum Status: Equatable {
        case pending
        case fulfilled
        case failed(reason: String)
    }

    let id: String
    let rewardTitle: String
    let pointsCost: Int
    let redeemedAt: Date
    let status: Status
    let voucherCode: String?
}

/// The real South African mobile networks RedeemActivity.kt offers for
/// airtime-style rewards (its MOBILE_NETWORKS constant), verbatim.
private let redeemMobileNetworks = ["MTN", "Vodacom", "Cell C", "Telkom"]

/// Real catalog/redeem screen — port of RedeemActivity.kt + activity_redeem.xml
/// + item_redeem_reward.xml. This is a genuinely separate screen from
/// RewardsView, matching Android: RedeemActivity is its own top-level
/// Activity launched from the main menu's own MenuAction.REDEEM, not nested
/// inside RewardsActivity. Every catalog entry and redemption shown here is
/// meant to be real data from the caller — an empty catalog or empty
/// history shows the same honest empty-state text Android does, never a
/// fabricated placeholder reward.
///
/// NOT wired into navigation yet — see the module-level doc comment on
/// RedeemCatalogItem above, and the PR description, for what the caller
/// still needs to provide.
struct RedeemView: View {
    /// Outcome of attempting a redemption — mirrors RedemptionOutcome in
    /// RedemptionEngine.kt (Submitted / Rejected(reason)).
    enum RedeemOutcome {
        case submitted
        case rejected(reason: String)
    }

    let availableBalance: Int
    let catalog: [RedeemCatalogItem]
    let history: [RedemptionRecord]
    /// Mirrors FirebaseConfig.isConfigured() — when false, shows the same
    /// "shared rewards backend isn't configured" notice Android does and
    /// skips the remote catalog pull entirely.
    let isConfigured: Bool
    /// Called when the user confirms a redemption (after supplying a mobile
    /// number / network if the item needs one) — mirrors
    /// RedeemActivity.submitRedeem() -> RedemptionEngine.redeem(). The
    /// caller owns the real network/db call and reports back the outcome;
    /// this view only renders the result the same way Android's Toast does.
    var onRedeem: (RedeemCatalogItem, _ mobileNumber: String?, _ network: String?) async -> RedeemOutcome

    @Environment(\.dismiss) private var dismiss

    /// The catalog item currently being confirmed via the mobile/network
    /// sheet — mirrors RedeemActivity.startRedeem()'s AlertDialog, shown
    /// only when the item requiresMobileNumber || requiresNetwork.
    @State private var pendingItem: RedeemCatalogItem?
    @State private var mobileNumberInput = ""
    @State private var selectedNetwork = redeemMobileNetworks[0]
    @State private var isSubmitting = false

    /// Transient inline banner standing in for Android's Toast — disappears
    /// on the next successful render, same as a Toast would.
    @State private var banner: (text: String, isError: Bool)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    balanceHeader
                    if let banner {
                        bannerView(banner)
                    }
                    if !isConfigured {
                        Text("The shared rewards backend isn't configured yet — Redeem isn't available on this build.")
                            .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2.opacity(0.95))
                            .accessibilityIdentifier("redeemNotConfiguredText")
                    }
                    catalogSection
                    historySection
                }
                .padding(16)
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("Redeem")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $pendingItem) { item in
                RedeemConfirmSheet(
                    item: item,
                    mobileNumber: $mobileNumberInput,
                    selectedNetwork: $selectedNetwork,
                    isSubmitting: isSubmitting,
                    onCancel: { pendingItem = nil },
                    onConfirm: { confirmRedeem(item) }
                )
            }
        }
    }

    // MARK: - Balance header
    // Plain bold-number header (no card background), matching
    // activity_redeem.xml's redeemBalance/redeemBalanceLabel TextViews,
    // which sit directly on the canvas unlike RewardsView's boxed levelCard.

    @ViewBuilder
    private var balanceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(availableBalance) points available to spend")
                .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                .accessibilityIdentifier("redeemBalance")
            Text("Use your VISION Points on real rewards.")
                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("redeemBalanceLabel")
        }
    }

    @ViewBuilder
    private func bannerView(_ banner: (text: String, isError: Bool)) -> some View {
        Text(banner.text)
            .font(.system(size: 13)).foregroundStyle(banner.isError ? DesignSystem.statusDangerText : DesignSystem.statusSuccess)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.bgCard))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.borderCard, lineWidth: 1))
            .accessibilityIdentifier("redeemStatusBanner")
    }

    // MARK: - Catalog
    // Each card ports item_redeem_reward.xml's title/description/cost/action
    // stack via DesignSystem.card, the same rounded-card component the rest
    // of the design system (and RewardsView) already uses.

    @ViewBuilder
    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if catalog.isEmpty {
                Text("No rewards are available right now.")
                    .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("redeemCatalogEmptyText")
            } else {
                ForEach(catalog) { item in
                    DesignSystem.card {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            Text(item.description)
                                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                            Text("\(item.pointsCost) pts")
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                .padding(.top, 4)

                            if let disabledReason = item.disabledReason {
                                Text(disabledReason)
                                    .font(.system(size: 13, weight: .bold)).foregroundStyle(DesignSystem.textMuted2)
                                    .padding(.horizontal, 20).padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(Capsule().fill(DesignSystem.bgCard))
                                    .overlay(Capsule().stroke(DesignSystem.borderCard, lineWidth: 1))
                                    .padding(.top, 10)
                            } else {
                                DesignSystem.primaryButton("Redeem for \(item.pointsCost) pts") {
                                    startRedeem(item)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 10)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("redeemCatalogCard_\(item.id)")
                }
            }
        }
    }

    // MARK: - History

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DesignSystem.sectionLabel("My Redemptions")
            if history.isEmpty {
                Text("You haven't redeemed anything yet.")
                    .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("redeemHistoryEmptyText")
            } else {
                ForEach(history) { redemption in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(redemption.rewardTitle) — \(redemption.pointsCost) pts")
                            .font(.system(size: 13)).foregroundStyle(.white)
                        Text("\(redemption.redeemedAt.formatted(date: .abbreviated, time: .shortened)) · \(statusLabel(redemption.status))")
                            .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                        if let code = redemption.voucherCode {
                            Text("Code: \(code)")
                                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                        }
                    }
                    .padding(.vertical, 10)
                    .accessibilityIdentifier("redeemHistoryRow_\(redemption.id)")
                }
            }
        }
    }

    private func statusLabel(_ status: RedemptionRecord.Status) -> String {
        switch status {
        case .pending: return "Pending — processed by hand, usually within a few days"
        case .fulfilled: return "Fulfilled"
        case .failed(let reason): return "Failed — \(reason) (points returned)"
        }
    }

    // MARK: - Redeem flow
    // Mirrors RedeemActivity.startRedeem(): items that need no extra info
    // submit immediately; items that need a mobile number and/or network
    // open a confirmation sheet first (Android's AlertDialog equivalent).

    private func startRedeem(_ item: RedeemCatalogItem) {
        if !item.requiresMobileNumber && !item.requiresNetwork {
            Task { await confirmRedeem(item, mobileNumber: nil, network: nil) }
            return
        }
        mobileNumberInput = ""
        selectedNetwork = redeemMobileNetworks[0]
        pendingItem = item
    }

    private func confirmRedeem(_ item: RedeemCatalogItem) {
        let mobileNumber = item.requiresMobileNumber ? mobileNumberInput.trimmingCharacters(in: .whitespaces) : nil
        let network = item.requiresNetwork ? selectedNetwork : nil
        Task {
            await confirmRedeem(item, mobileNumber: (mobileNumber?.isEmpty ?? true) ? nil : mobileNumber, network: network)
        }
    }

    private func confirmRedeem(_ item: RedeemCatalogItem, mobileNumber: String?, network: String?) async {
        isSubmitting = true
        let outcome = await onRedeem(item, mobileNumber, network)
        isSubmitting = false
        pendingItem = nil
        switch outcome {
        case .submitted:
            banner = (text: "Redemption submitted — you'll see it below once it's processed.", isError: false)
        case .rejected(let reason):
            banner = (text: reason, isError: true)
        }
    }
}

/// The mobile-number / network confirmation step — SwiftUI's sheet
/// equivalent of RedeemActivity.startRedeem()'s AlertDialog (title + an
/// EditText and/or Spinner + Confirm/Cancel buttons).
private struct RedeemConfirmSheet: View {
    let item: RedeemCatalogItem
    @Binding var mobileNumber: String
    @Binding var selectedNetwork: String
    let isSubmitting: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.title)
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                Text("\(item.pointsCost) pts")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(DesignSystem.statusSuccess)

                if item.requiresMobileNumber {
                    TextField("", text: $mobileNumber, prompt: Text("Mobile number (e.g. 082 123 4567)").foregroundColor(DesignSystem.textMuted2))
                        .keyboardType(.phonePad)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.bgCard))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.borderCard, lineWidth: 1))
                        .accessibilityIdentifier("redeemMobileNumberField")
                }

                if item.requiresNetwork {
                    Picker("Network", selection: $selectedNetwork) {
                        ForEach(redeemMobileNetworks, id: \.self) { network in
                            Text(network).tag(network)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("redeemNetworkPicker")
                }

                Spacer()

                DesignSystem.primaryButton(isSubmitting ? "Redeeming…" : "Redeem") {
                    onConfirm()
                }
                .frame(maxWidth: .infinity)
                .disabled(isSubmitting)
                .accessibilityIdentifier("redeemConfirmButton")
            }
            .padding(20)
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle(item.title)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
