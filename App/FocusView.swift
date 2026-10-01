import SwiftUI

/// Real Focus Mode screen — direct port of FocusActivity.kt: start a
/// session from a real duration preset, see a real live countdown against
/// FocusManager's real endsAt timestamp, stop it early, and manage a real
/// user-authored blocklist (no built-in "distracting sites" list — same
/// as Android/desktop, this app has no honest basis to curate one itself).
struct FocusView: View {
    @ObservedObject var focusStore: FocusStore
    @ObservedObject var focusManager: FocusManager
    @Environment(\.dismiss) private var dismiss

    /// Direct port of FocusActivity.kt's SESSION_PRESETS_MIN.
    private static let sessionPresetsMinutes = [15, 25, 45, 60, 90]

    @State private var selectedPreset = 25
    @State private var blockedDomains: [String] = []
    @State private var newDomainText = ""
    @State private var now = Date()
    // @State, deliberately, not a plain `let`: Timer.publish(...).autoconnect()
    // starts a real, already-running Timer the instant it's created, and a
    // plain stored `let` gets re-created (reconnecting a brand-new Timer)
    // on every body re-evaluation of this struct — a well-documented real
    // Combine leak. Opening FocusView twice in one real CI run (start a
    // session, close, reopen to clean up the blocklist) leaked enough
    // independently-firing Timers to stall the app's idle detection for a
    // genuine ~60 real seconds, caught as a real CI timeout, not a guess.
    // @State preserves this publisher's identity across re-renders for
    // the same view identity instead of reconnecting a new one each time.
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let session = focusManager.activeSession {
                        activeSessionCard(session)
                    } else {
                        startSessionCard
                    }
                    blocklistSection
                }
                .padding(16)
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("Focus Mode")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: refreshBlockedDomains)
        .onReceive(tick) { now = $0 }
    }

    @ViewBuilder
    private func activeSessionCard(_ session: ActiveFocusSession) -> some View {
        DesignSystem.card {
            VStack(spacing: 12) {
                DesignSystem.sectionLabel("Session in progress")
                Text(remainingText(session))
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("focusCountdownLabel")
                if session.blockedAttempts > 0 {
                    Text("\(session.blockedAttempts) blocked attempt\(session.blockedAttempts == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.textMuted2)
                        .accessibilityIdentifier("focusBlockedAttemptsLabel")
                }
                DesignSystem.primaryButton("Stop session") {
                    focusManager.stopSession()
                }
                .accessibilityIdentifier("stopFocusSessionButton")
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var startSessionCard: some View {
        DesignSystem.card {
            VStack(alignment: .leading, spacing: 12) {
                DesignSystem.sectionLabel("Start a focus session")
                HStack(spacing: 8) {
                    ForEach(Self.sessionPresetsMinutes, id: \.self) { minutes in
                        Button(action: { selectedPreset = minutes }) {
                            Text("\(minutes)m")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(
                                    Capsule().fill(minutes == selectedPreset ? AnyShapeStyle(DesignSystem.brandGradient) : AnyShapeStyle(DesignSystem.bgCanvas))
                                )
                                .overlay(Capsule().stroke(minutes == selectedPreset ? Color.clear : DesignSystem.borderCard, lineWidth: 1))
                        }
                        .accessibilityIdentifier("focusPreset_\(minutes)")
                    }
                }
                DesignSystem.primaryButton("Start \(selectedPreset)-minute session") {
                    startSession()
                }
                .accessibilityIdentifier("startFocusSessionButton")
            }
        }
    }

    @ViewBuilder
    private var blocklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DesignSystem.sectionLabel("Blocked sites")
            HStack {
                TextField("e.g. youtube.com", text: $newDomainText, onCommit: addDomain)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCard))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("addBlockedDomainField")
                Button(action: addDomain) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newDomainText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("addBlockedDomainButton")
            }

            if blockedDomains.isEmpty {
                Text("No sites blocked yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("emptyBlocklistLabel")
            } else {
                ForEach(blockedDomains, id: \.self) { domain in
                    HStack(spacing: 12) {
                        FaviconView(host: domain)
                        Text(domain).foregroundStyle(.white)
                        Spacer()
                        Button(action: { removeDomain(domain) }) {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(DesignSystem.textMuted2)
                        }
                        .accessibilityIdentifier("removeBlockedDomain_\(domain)")
                    }
                    .padding(.vertical, 6)
                    // A single-child-ish composition like this is exactly
                    // the shape that bit the bookmark row in Phase 1 —
                    // SwiftUI's default accessibility merging can fold the
                    // remove button's own identifier into this row's.
                    // .contain keeps every child, including the button,
                    // independently reachable by a UI test.
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("blockedDomainRow_\(domain)")
                }
            }
        }
    }

    private func remainingText(_ session: ActiveFocusSession) -> String {
        let remaining = max(0, session.endsAt.timeIntervalSince(now))
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startSession() {
        let id = UUID().uuidString
        let startedAt = Date()
        try? focusStore.startSession(id: id, startedAt: startedAt, plannedMinutes: selectedPreset)
        focusManager.startSession(id: id, startedAt: startedAt, plannedMinutes: selectedPreset)
    }

    private func refreshBlockedDomains() {
        blockedDomains = (try? focusStore.listBlockedDomains()) ?? []
    }

    private func addDomain() {
        let trimmed = newDomainText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? focusStore.addBlockedDomain(trimmed)
        newDomainText = ""
        refreshBlockedDomains()
        focusManager.setBlockedDomains(blockedDomains)
    }

    private func removeDomain(_ domain: String) {
        try? focusStore.removeBlockedDomain(domain)
        refreshBlockedDomains()
        focusManager.setBlockedDomains(blockedDomains)
    }
}
