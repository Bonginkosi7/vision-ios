import Foundation
import GRDB
import VisionCore

enum LicenceMigrations {
    static func register(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v18_licence_usage") { db in
            try db.create(table: "offlineSyncUsage") { t in
                t.primaryKey("day", .text)
                t.column("offlineSyncs", .integer).notNull()
            }
        }
    }
}

/// Counts offline syncs per UTC day on this device (every page saved for offline use). The count stays on the
/// device unless a licence is active, in which case the daily totals are reported for billing.
final class LicenceUsageStore {
    static let shared = LicenceUsageStore()
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) { self.dbQueue = dbQueue }

    func recordSync(now: Date = Date()) {
        let day = LicenceCore.utcDay(now)
        _ = try? dbQueue.write { db in
            try db.execute(sql: "INSERT INTO offlineSyncUsage (day, offlineSyncs) VALUES (?, 1) ON CONFLICT(day) DO UPDATE SET offlineSyncs = offlineSyncs + 1", arguments: [day])
        }
    }

    /// The most recent days with any syncs, oldest first.
    func recentDays(limit: Int = 62) -> [(day: String, syncs: Int)] {
        let rows = (try? dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT day, offlineSyncs FROM offlineSyncUsage ORDER BY day DESC LIMIT ?", arguments: [limit])
        }) ?? []
        return rows.reversed().map { (day: $0["day"], syncs: $0["offlineSyncs"]) }
    }

    func total(forMonth month: String) -> Int {
        let value = try? dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(offlineSyncs), 0) FROM offlineSyncUsage WHERE day LIKE ?", arguments: ["\(month)-%"])
        }
        return (value ?? nil) ?? 0
    }
}

/// The offline plug-in licence on this device: activate with a key, keep the signed certificate, renew it when
/// due, and report the offline-sync counts. Nothing is sent unless a licence is active.
@MainActor
final class LicenceManager: ObservableObject {
    static let shared = LicenceManager()

    struct Status: Equatable {
        var state: LicenceState = .none
        var org = ""
        var plan = ""
        var seats = 0
        var expiresAt: Date?
        var pricePerSyncCents = 0
        var includedSyncs = 0
        var syncsThisMonth = 0
        var billableThisMonth = 0
        var verified = false
        var notice = ""
    }

    @Published private(set) var status = Status()

    private let defaults = UserDefaults.standard
    private let certificateKey = "licence_certificate"
    private let signatureKey = "licence_signature"
    private let rejectedKey = "licence_rejected"
    private let tokenAccount = "vision.licence.activationToken"
    private var timer: Timer?

    private var publicKey: String { Bundle.main.object(forInfoDictionaryKey: "VisionLicencePublicKey") as? String ?? "" }
    private var installationID: String { AppSettings.analyticsInstallationID ?? "" }

    private init() { refresh() }

    // MARK: State

    private func currentCertificate() -> (certificate: LicenceCertificate, verified: Bool)? {
        guard let cert = defaults.string(forKey: certificateKey), let sig = defaults.string(forKey: signatureKey) else { return nil }
        if case let .ok(certificate, verified) = LicenceCore.readCertificate(certificate: cert, signature: sig, publicKey: publicKey) {
            return (certificate, verified)
        }
        return nil
    }

    func refresh() {
        let syncs = LicenceUsageStore.shared.total(forMonth: String(LicenceCore.utcDay(Date()).prefix(7)))
        guard let (certificate, verified) = currentCertificate() else {
            status = Status(syncsThisMonth: syncs)
            return
        }
        var state = LicenceCore.state(of: certificate, installationId: installationID, now: Date())
        let rejected = defaults.string(forKey: rejectedKey)
        if let rejected { state = rejected == "licence_expired" ? .expired : .otherDevice }
        status = Status(
            state: state, org: certificate.org, plan: certificate.plan, seats: certificate.seats, expiresAt: certificate.expiresAt,
            pricePerSyncCents: certificate.pricePerSyncCents, includedSyncs: certificate.includedSyncs,
            syncsThisMonth: syncs, billableThisMonth: LicenceCore.billableSyncs(total: syncs, included: certificate.includedSyncs),
            verified: verified, notice: rejected.map(LicenceCore.describe(error:)) ?? ""
        )
    }

    // MARK: Server

    private func post(_ path: String, _ body: [String: Any]) async -> (status: Int, json: [String: Any]) {
        guard AnalyticsConfig.isConfigured(), let url = URL(string: AnalyticsConfig.baseURL + path),
              let data = try? JSONSerialization.data(withJSONObject: body) else { return (0, ["error": "offline"]) }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AnalyticsConfig.writeKey, forHTTPHeaderField: "x-vision-write-key")
        request.httpBody = data
        guard let (responseData, response) = try? await URLSession.shared.data(for: request), let http = response as? HTTPURLResponse else {
            return (0, ["error": "offline"])
        }
        return (http.statusCode, (try? JSONSerialization.jsonObject(with: responseData) as? [String: Any]) ?? [:])
    }

    func activate(key: String) async -> (ok: Bool, message: String) {
        guard !installationID.isEmpty else { return (false, LicenceCore.describe(error: "other")) }
        let reply = await post("/v1/licence/activate", ["key": key, "installationId": installationID, "platform": "ios", "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""])
        guard reply.status == 200, let cert = reply.json["certificate"] as? String, let sig = reply.json["signature"] as? String, let token = reply.json["activationToken"] as? String else {
            return (false, LicenceCore.describe(error: reply.json["error"] as? String ?? "other"))
        }
        guard case let .ok(certificate, _) = LicenceCore.readCertificate(certificate: cert, signature: sig, publicKey: publicKey) else {
            return (false, "The licence server's answer couldn't be verified, so the licence was not activated.")
        }
        defaults.set(cert, forKey: certificateKey)
        defaults.set(sig, forKey: signatureKey)
        defaults.removeObject(forKey: rejectedKey)
        KeychainStore.set(token, forKey: tokenAccount)
        refresh()
        Task { await reportUsage() }
        return (true, "Licensed to \(certificate.org).")
    }

    func deactivate() async {
        if let (certificate, _) = currentCertificate(), let token = KeychainStore.get(forKey: tokenAccount) {
            _ = await post("/v1/licence/deactivate", ["licenceId": certificate.licenceId, "installationId": installationID, "activationToken": token])
        }
        forget()
    }

    /// Removes the licence from this device (also used when erasing all data).
    func forget() {
        defaults.removeObject(forKey: certificateKey)
        defaults.removeObject(forKey: signatureKey)
        defaults.removeObject(forKey: rejectedKey)
        KeychainStore.delete(forKey: tokenAccount)
        refresh()
    }

    /// Sends this device's offline-sync totals — only when a licence is active. Repeats are harmless: the server keeps the larger figure per day.
    func reportUsage() async {
        guard let (certificate, _) = currentCertificate(), defaults.string(forKey: rejectedKey) == nil,
              let token = KeychainStore.get(forKey: tokenAccount) else { return }
        let days = LicenceUsageStore.shared.recentDays().filter { $0.syncs > 0 }.map { ["day": $0.day, "offlineSyncs": $0.syncs] as [String: Any] }
        guard !days.isEmpty else { return }
        let reply = await post("/v1/licence/usage", ["licenceId": certificate.licenceId, "installationId": installationID, "activationToken": token, "days": days])
        if reply.status == 401 || reply.status == 403 { markRejected(reply.json["error"] as? String ?? "not_activated") }
    }

    /// Asks the server for a fresh certificate once the current one is due; the licence keeps working while offline.
    func renewIfDue() async {
        guard let (certificate, _) = currentCertificate(), defaults.string(forKey: rejectedKey) == nil,
              LicenceCore.state(of: certificate, installationId: installationID, now: Date()) == .renewDue,
              let token = KeychainStore.get(forKey: tokenAccount) else { return }
        let reply = await post("/v1/licence/renew", ["licenceId": certificate.licenceId, "installationId": installationID, "activationToken": token])
        if reply.status == 200, let cert = reply.json["certificate"] as? String, let sig = reply.json["signature"] as? String,
           case .ok = LicenceCore.readCertificate(certificate: cert, signature: sig, publicKey: publicKey) {
            defaults.set(cert, forKey: certificateKey)
            defaults.set(sig, forKey: signatureKey)
            refresh()
        } else if reply.status == 401 || reply.status == 403 {
            markRejected(reply.json["error"] as? String ?? "not_activated")
        }
    }

    private func markRejected(_ code: String) {
        defaults.set(code, forKey: rejectedKey)
        refresh()
    }

    /// Renews if due, then reports usage. Called at launch and every 30 minutes while the app is in use.
    func tick() async {
        await renewIfDue()
        await reportUsage()
        refresh()
    }

    func startBackgroundWork() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            await self.tick()
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { _ in
            Task { @MainActor in await LicenceManager.shared.tick() }
        }
    }
}
