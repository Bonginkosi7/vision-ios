import SwiftUI

/// UI-layer shape of the fields a catalog entry actually renders (mirrors
/// RedeemActivity.kt's CachedRewardCatalogEntry). The real data layer lives in
/// RedemptionStore; RedeemContainerView maps its models onto these plain values
/// so this view stays a pure renderer.
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

/// Only the fields "My Redemptions" actually shows.
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
/// + item_redeem_reward.xml, a separate screen from Rewards (as on Android,
/// where RedeemActivity is its own Activity). Every catalog entry and
/// redemption is real data from the caller; an empty catalog or history shows
/// the same honest empty text Android does, never a placeholder reward.
///
/// Layout: the balance up top, then each reward as one card with a single
/// primary action. Colour is used only for outcomes — green for a fulfilled
/// redemption or success message, red for failed ones.
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
    /// number / network if the item needs one). The caller owns the real
    /// network/db call and reports back the outcome; this view only renders it.
    var onRedeem: (RedeemCatalogItem, _ mobileNumber: String?, _ network: String?) async -> RedeemOutcome

    @Environment(\.dismiss) private var dismiss

    /// The catalog item currently being confirmed via the mobile/network
    /// sheet — shown only when the item requiresMobileNumber || requiresNetwork.
    @State private var pendingItem: RedeemCatalogItem?
    @State private var mobileNumberInput = ""
    @State private var selectedNetwork = redeemMobileNetworks[0]
    @State private var isSubmitting = false

    /// Transient inline banner standing in for Android's Toast.
    @State private var banner: (text: String, isError: Bool)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Space.xl) {
                    balanceHeader
                    if let banner {
                        bannerView(banner)
                    }
                    if !isConfigured {
                        Text("The shared rewards backend isn't configured yet — Redeem isn't available on this build.")
                            .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                            .accessibilityIdentifier("redeemNotConfiguredText")
                    }
                    catalogSection
                    historySection
                }
                .padding(DesignSystem.Space.l)
            }
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
            .visionScreen()
        }
    }

    // MARK: - Balance

    private var balanceHeader: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.xs) {
            Text("\(availableBalance) points available to spend")
                .font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                .accessibilityIdentifier("redeemBalance")
            Text("Use your VISION Points on real rewards.")
                .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("redeemBalanceLabel")
        }
    }

    private func bannerView(_ banner: (text: String, isError: Bool)) -> some View {
        Text(banner.text)
            .font(.system(size: 14)).foregroundStyle(banner.isError ? DesignSystem.statusDangerText : DesignSystem.statusSuccess)
            .padding(DesignSystem.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous).fill(DesignSystem.bgCard))
            .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous).stroke(DesignSystem.borderCard, lineWidth: 1))
            .accessibilityIdentifier("redeemStatusBanner")
    }

    // MARK: - Catalog

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.m) {
            DesignSystem.sectionLabel("Rewards")
            if catalog.isEmpty {
                Text("No rewards are available right now.")
                    .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("redeemCatalogEmptyText")
            } else {
                ForEach(catalog) { item in
                    DesignSystem.card {
                        VStack(alignment: .leading, spacing: DesignSystem.Space.xs) {
                            Text(item.title)
                                .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            Text(item.description)
                                .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(item.pointsCost) pts")
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                                .padding(.top, DesignSystem.Space.xs)

                            if let disabledReason = item.disabledReason {
                                Text(disabledReason)
                                    .font(.system(size: 14, weight: .medium)).foregroundStyle(DesignSystem.textMuted2)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .overlay(Capsule().stroke(DesignSystem.borderCard, lineWidth: 1))
                                    .padding(.top, DesignSystem.Space.m)
                            } else {
                                DesignSystem.primaryButton("Redeem for \(item.pointsCost) pts", fullWidth: true) {
                                    startRedeem(item)
                                }
                                .padding(.top, DesignSystem.Space.m)
                            }
                        }
                    }
                    .accessibilityIdentifier("redeemCatalogCard_\(item.id)")
                }
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.m) {
            DesignSystem.sectionLabel("My redemptions")
            if history.isEmpty {
                Text("You haven't redeemed anything yet.")
                    .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("redeemHistoryEmptyText")
            } else {
                DesignSystem.card {
                    ForEach(Array(history.enumerated()), id: \.element.id) { index, redemption in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(redemption.rewardTitle) — \(redemption.pointsCost) pts")
                                .font(.system(size: 15)).foregroundStyle(.white)
                            Text(redemption.redeemedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                            Text(statusLabel(redemption.status))
                                .font(.system(size: 13)).foregroundStyle(statusColor(redemption.status))
                            if let code = redemption.voucherCode {
                                Text("Code: \(code)")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                                    .padding(.top, 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DesignSystem.Space.m)
                        .accessibilityIdentifier("redeemHistoryRow_\(redemption.id)")
                        if index < history.count - 1 { DesignSystem.divider() }
                    }
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

    private func statusColor(_ status: RedemptionRecord.Status) -> Color {
        switch status {
        case .pending: return DesignSystem.textMuted2
        case .fulfilled: return DesignSystem.statusSuccess
        case .failed: return DesignSystem.statusDangerText
        }
    }

    // MARK: - Redeem flow
    // Items that need no extra info submit immediately; items that need a
    // mobile number and/or network open a confirmation sheet first.

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

/// The mobile-number / network confirmation step — a sheet standing in for
/// RedeemActivity.startRedeem()'s AlertDialog.
private struct RedeemConfirmSheet: View {
    let item: RedeemCatalogItem
    @Binding var mobileNumber: String
    @Binding var selectedNetwork: String
    let isSubmitting: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSystem.Space.l) {
                Text(item.title)
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                Text("\(item.pointsCost) pts")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(DesignSystem.textMuted2)

                if item.requiresMobileNumber {
                    TextField("", text: $mobileNumber, prompt: Text("Mobile number (e.g. 082 123 4567)").foregroundColor(DesignSystem.textMuted2))
                        .keyboardType(.phonePad)
                        .foregroundStyle(.white)
                        .padding(DesignSystem.Space.m)
                        .background(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous).fill(DesignSystem.bgRaised))
                        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous).stroke(DesignSystem.borderCard, lineWidth: 1))
                        .accessibilityLabel("Mobile number")
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

                DesignSystem.primaryButton(isSubmitting ? "Redeeming…" : "Redeem", fullWidth: true) {
                    onConfirm()
                }
                .disabled(isSubmitting)
                .accessibilityIdentifier("redeemConfirmButton")
            }
            .padding(DesignSystem.Space.xl)
            .navigationTitle(item.title)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
            .visionScreen()
        }
    }
}
