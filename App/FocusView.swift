import SwiftUI

/// Real Focus Mode screen — direct port of FocusActivity.kt: start a session
/// from a real duration preset, see a real live countdown against
/// FocusManager's real endsAt timestamp, stop it early, and manage a real
/// user-authored blocklist (no built-in "distracting sites" list — same as
/// Android/desktop, this app has no honest basis to curate one itself).
///
/// Layout: when idle, pick a duration and start; when running, the countdown
/// is the whole point and stopping is a quiet secondary action. The selected
/// duration is shown by a filled chip (and the `selected` accessibility trait),
/// not by colour.
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
    // plain stored `let` gets re-created (reconnecting a brand-new Timer) on
    // every body re-evaluation — a well-documented real Combine leak. Opening
    // FocusView twice in one real CI run leaked enough independently-firing
    // Timers to stall the app's idle detection for ~60 real seconds, caught as
    // a real CI timeout. @State preserves this publisher's identity across
    // re-renders for the same view identity.
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Space.xl) {
                    if let session = focusManager.activeSession {
                        activeSessionCard(session)
                    } else {
                        startSessionCard
                    }
                    blocklistSection
                }
                .padding(DesignSystem.Space.l)
            }
            .navigationTitle("Focus Mode")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .visionScreen()
        }
        .onAppear(perform: refreshBlockedDomains)
        .onReceive(tick) { now = $0 }
    }

    private func activeSessionCard(_ session: ActiveFocusSession) -> some View {
        DesignSystem.card {
            VStack(spacing: DesignSystem.Space.m) {
                DesignSystem.sectionLabel("Session in progress")
                Text(remainingText(session))
                    .font(.system(size: 48, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("focusCountdownLabel")
                if session.blockedAttempts > 0 {
                    Text("\(session.blockedAttempts) blocked attempt\(session.blockedAttempts == 1 ? "" : "s")")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.textMuted2)
                        .accessibilityIdentifier("focusBlockedAttemptsLabel")
                }
                DesignSystem.secondaryButton("Stop session") {
                    focusManager.stopSession()
                }
                .accessibilityIdentifier("stopFocusSessionButton")
                .padding(.top, DesignSystem.Space.s)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var startSessionCard: some View {
        DesignSystem.card {
            VStack(alignment: .leading, spacing: DesignSystem.Space.l) {
                DesignSystem.sectionLabel("Start a focus session")
                HStack(spacing: DesignSystem.Space.s) {
                    ForEach(Self.sessionPresetsMinutes, id: \.self) { minutes in
                        let selected = minutes == selectedPreset
                        Button(action: { selectedPreset = minutes }) {
                            Text("\(minutes)m")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(selected ? Color.black : Color.white)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(Capsule().fill(selected ? Color.white : Color.clear))
                                .overlay(Capsule().stroke(selected ? Color.clear : DesignSystem.borderCard, lineWidth: 1))
                        }
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("focusPreset_\(minutes)")
                    }
                }
                DesignSystem.primaryButton("Start \(selectedPreset)-minute session", fullWidth: true) {
                    startSession()
                }
                .accessibilityIdentifier("startFocusSessionButton")
            }
        }
    }

    private var blocklistSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.m) {
            DesignSystem.sectionLabel("Blocked sites")
            HStack(spacing: DesignSystem.Space.s) {
                TextField("", text: $newDomainText, prompt: Text("e.g. youtube.com").foregroundColor(DesignSystem.textMuted2))
                    .onSubmit(addDomain)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal, DesignSystem.Space.m).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous).fill(DesignSystem.bgRaised))
                    .foregroundStyle(.white)
                    .accessibilityLabel("Site to block")
                    .accessibilityIdentifier("addBlockedDomainField")
                Button(action: addDomain) {
                    Text("Add")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(newDomainText.trimmingCharacters(in: .whitespaces).isEmpty ? DesignSystem.textMuted2 : .white)
                        .padding(.horizontal, DesignSystem.Space.l).frame(minHeight: 44)
                }
                .disabled(newDomainText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("addBlockedDomainButton")
            }

            if blockedDomains.isEmpty {
                Text("No sites blocked yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("emptyBlocklistLabel")
            } else {
                DesignSystem.card {
                    ForEach(Array(blockedDomains.enumerated()), id: \.element) { index, domain in
                        HStack(spacing: DesignSystem.Space.m) {
                            FaviconView(host: domain, size: 28)
                            Text(domain).font(.system(size: 15)).foregroundStyle(.white)
                            Spacer()
                            Button(action: { removeDomain(domain) }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(DesignSystem.textMuted2)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityIdentifier("removeBlockedDomain_\(domain)")
                        }
                        .padding(.vertical, DesignSystem.Space.xs)
                        // `.contain` keeps the remove button independently
                        // reachable: SwiftUI's default merging can fold a
                        // child button's identifier into its row's (the same
                        // thing that bit the Phase 1 bookmark row).
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("blockedDomainRow_\(domain)")
                        if index < blockedDomains.count - 1 { DesignSystem.divider() }
                    }
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
