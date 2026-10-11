import SwiftUI
import VisionCore

/// Settings → Licence: enter the key an organisation gave you to activate the offline plug-in licence, and see
/// this month's offline syncs. Without a licence nothing about usage is sent anywhere.
struct LicenceSection: View {
    @ObservedObject private var manager = LicenceManager.shared
    @State private var keyInput = ""
    @State private var message = "Enter the key you were given, e.g. VSN-XXXX-XXXX-XXXX-XXXX."
    @State private var busy = false
    @State private var confirmDeactivate = false

    private var status: LicenceManager.Status { manager.status }
    private var licensed: Bool { status.state != .none }

    var body: some View {
        Section {
            if licensed {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Licensed to \(status.org)").font(.system(size: 16, weight: .medium))
                    Text(detailLine).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("licenceStatusText")
                Button("Deactivate on this device", role: .destructive) { confirmDeactivate = true }
                    .accessibilityIdentifier("licenceDeactivateButton")
                    .confirmationDialog("Deactivate the licence on this device? This frees its place for another device.", isPresented: $confirmDeactivate, titleVisibility: .visible) {
                        Button("Deactivate", role: .destructive) { Task { await manager.deactivate() } }
                        Button("Cancel", role: .cancel) {}
                    }
            } else {
                TextField("VSN-XXXX-XXXX-XXXX-XXXX", text: $keyInput)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .accessibilityIdentifier("licenceKeyField")
                Button(busy ? "Checking…" : "Activate") { activate() }
                    .disabled(busy || keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("licenceActivateButton")
                Text(message).font(.system(size: 13)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("licenceMessage")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Offline syncs this month").font(.system(size: 15))
                Text(usageLine).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("licenceUsageText")
        } header: {
            Text("Licence")
        } footer: {
            Text("Organisations that license VISION's offline plug-in get a key. Without one, VISION works as usual and nothing about your usage is sent anywhere.")
        }
        .onAppear { manager.refresh() }
    }

    private var detailLine: String {
        var parts: [String] = []
        if !status.plan.isEmpty { parts.append(status.plan) }
        if let expires = status.expiresAt { parts.append("valid until \(expires.formatted(date: .abbreviated, time: .omitted))") }
        if status.state == .renewDue { parts.append("will renew when you're next online") }
        if status.state == .expired { parts.append("expired") }
        if status.state == .otherDevice { parts.append("not active on this device") }
        if !status.verified { parts.append("development build: signature not checked") }
        if !status.notice.isEmpty { parts.append(status.notice) }
        return parts.joined(separator: " · ")
    }

    private var usageLine: String {
        let syncs = status.syncsThisMonth.formatted()
        guard licensed else { return "\(syncs) — pages saved for offline use on this device." }
        return "\(syncs) — \(status.billableThisMonth.formatted()) beyond the \(status.includedSyncs.formatted()) included, at \(LicenceCore.formatRand(cents: status.pricePerSyncCents)) each. Reported to your organisation's licence."
    }

    private func activate() {
        busy = true
        message = "Checking the key…"
        Task {
            let result = await manager.activate(key: keyInput.trimmingCharacters(in: .whitespacesAndNewlines))
            message = result.message
            if result.ok { keyInput = "" }
            busy = false
        }
    }
}
