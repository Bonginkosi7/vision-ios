import Foundation
import GRDB
import VisionCore

/// Real local cache of the last-pulled reward catalog — direct port of
/// RewardCatalogDbHelper.kt's real columns. Never written to by a user
/// action here; only ever overwritten wholesale by `pullCatalog()` from
/// the real shared Firestore `rewardCatalog` collection, which desktop's
/// own admin manages (AdminSession.swift/CatalogSync.ts there). This app
/// never invents or edits a reward.
public struct RewardCatalogCacheEntry: Codable, Identifiable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "rewardCatalogCache"
    public var id: String
    public var title: String
    public var entryDescription: String
    public var category: String
    public var rewardType: String
    public var pointsCost: Int
    public var currencyValue: Double?
    public var currency: String?
    public var icon: String?
    public var fulfillmentType: String
    public var status: String
    public var stock: Int?
    public var redemptionLimit: Int?
    public var dailyRedemptionLimit: Int?
    /// Deliberately checked against THIS DEVICE's own real local
    /// redemption count, not a global one — see RedemptionEligibility.
    public var userRedemptionLimit: Int?
    public var startDate: Date?
    public var endDate: Date?
    public var terms: String?
    public var instructions: String?
    public var isActive: Bool
    public var requiresMobileNumber: Bool
    public var requiresNetwork: Bool
    public var redeemedCount: Int
    public var redeemedToday: Int
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, entryDescription = "description", category, rewardType, pointsCost, currencyValue,
             currency, icon, fulfillmentType, status, stock, redemptionLimit, dailyRedemptionLimit,
             userRedemptionLimit, startDate, endDate, terms, instructions, isActive, requiresMobileNumber,
             requiresNetwork, redeemedCount, redeemedToday, updatedAt
    }
}

/// This device's own real redemption ledger — direct port of
/// RedemptionDbHelper.kt. Two real jobs in one table, exactly as there:
/// (1) it's what actually deducts this device's VISION Points balance
/// (see RewardStore.availableBalance()) the moment a redemption is
/// submitted; (2) it's a durable upload outbox (`syncStatus`
/// pendingUpload -> synced) so a redemption made offline is never
/// silently lost. The row's own id doubles as the eventual Firestore
/// document id, so a retried upload can never create a duplicate.
public struct Redemption: Codable, Identifiable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "redemption"
    public enum Status: String, Codable { case pending = "PENDING", fulfilled = "FULFILLED", failed = "FAILED" }
    public enum SyncStatus: String, Codable { case pendingUpload = "PENDING_UPLOAD", synced = "SYNCED" }

    public var id: String
    public var rewardID: String
    public var rewardTitle: String
    public var category: String
    public var pointsCost: Int
    public var fulfillmentType: String
    public var mobileNumber: String?
    public var network: String?
    public var status: Status
    public var voucherCode: String?
    public var providerReference: String?
    public var failureReason: String?
    public var redeemedAt: Date
    public var fulfilledAt: Date?
    public var syncStatus: SyncStatus
}

/// GRDB migrations for the two tables above — a new migration added to
/// AppDatabase's own shared migrator (see AppDatabase.swift), not a
/// separate database: this repo's own established "one shared .sqlite
/// file, one *Store.swift per feature" convention.
enum RedemptionMigrations {
    static func register(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v14_redeem") { db in
            try db.create(table: "rewardCatalogCache") { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("description", .text).notNull()
                t.column("category", .text).notNull()
                t.column("rewardType", .text).notNull()
                t.column("pointsCost", .integer).notNull()
                t.column("currencyValue", .double)
                t.column("currency", .text)
                t.column("icon", .text)
                t.column("fulfillmentType", .text).notNull()
                t.column("status", .text).notNull()
                t.column("stock", .integer)
                t.column("redemptionLimit", .integer)
                t.column("dailyRedemptionLimit", .integer)
                t.column("userRedemptionLimit", .integer)
                t.column("startDate", .datetime)
                t.column("endDate", .datetime)
                t.column("terms", .text)
                t.column("instructions", .text)
                t.column("isActive", .boolean).notNull()
                t.column("requiresMobileNumber", .boolean).notNull()
                t.column("requiresNetwork", .boolean).notNull()
                t.column("redeemedCount", .integer).notNull().defaults(to: 0)
                t.column("redeemedToday", .integer).notNull().defaults(to: 0)
                t.column("updatedAt", .datetime).notNull()
            }

            try db.create(table: "redemption") { t in
                t.primaryKey("id", .text)
                t.column("rewardID", .text).notNull()
                t.column("rewardTitle", .text).notNull()
                t.column("category", .text).notNull()
                t.column("pointsCost", .integer).notNull()
                t.column("fulfillmentType", .text).notNull()
                t.column("mobileNumber", .text)
                t.column("network", .text)
                t.column("status", .text).notNull()
                t.column("voucherCode", .text)
                t.column("providerReference", .text)
                t.column("failureReason", .text)
                t.column("redeemedAt", .datetime).notNull()
                t.column("fulfilledAt", .datetime)
                t.column("syncStatus", .text).notNull()
            }
            try db.create(index: "idx_redemption_rewardID", on: "redemption", columns: ["rewardID"])
        }
    }
}

public enum RedemptionOutcome: Equatable {
    case submitted
    case rejected(reason: String)

    public static func == (lhs: RedemptionOutcome, rhs: RedemptionOutcome) -> Bool {
        switch (lhs, rhs) {
        case (.submitted, .submitted): return true
        case let (.rejected(a), .rejected(b)): return a == b
        default: return false
        }
    }
}

/// The real, one entry point for Redeem on iOS — combines what Android
/// splits across RewardCatalogRemote.kt, RedemptionEngine.kt,
/// RedemptionUploader.kt, and RedemptionSyncWorker.kt into one store
/// class, matching this repo's own established per-feature *Store.swift
/// convention (RewardStore, FocusStore, etc. already do the same: one
/// class owning both local persistence and whatever real I/O the feature
/// needs).
///
/// **Disclosed scope trim**: Android/desktop sync pending uploads and
/// refresh statuses via a real periodic background job
/// (RedemptionSyncWorker.kt / WorkManager). iOS has no background-task
/// infrastructure built yet at all — confirmed nothing else in this repo
/// uses BGTaskScheduler either (VisionReadyView's own real "Keeping Pages
/// Up to Date" disclosure already says background refresh isn't built on
/// iOS yet). Rather than build a separate BGTaskScheduler integration
/// speculatively, `sync()` here runs on real, concrete triggers instead
/// (app foreground, RedeemView appearing) — an honest, smaller real
/// behavior, not a silent gap.
@MainActor
final class RedemptionStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    // MARK: - Local reads

    func catalog() throws -> [RewardCatalogCacheEntry] {
        try dbQueue.read { db in
            try RewardCatalogCacheEntry
                .filter(["ACTIVE", "SOLD_OUT", "COMING_SOON"].contains(Column("status")))
                .order(Column("pointsCost").asc)
                .fetchAll(db)
        }
    }

    func history() throws -> [Redemption] {
        try dbQueue.read { db in try Redemption.order(Column("redeemedAt").desc).fetchAll(db) }
    }

    /// The real sum this device has spent that hasn't been refunded —
    /// subtracted from real earned points to get the displayed balance.
    /// Matches desktop's own "balance excludes non-terminal-failed spend"
    /// model and RedemptionDbHelper.activeSpend() exactly.
    func activeSpend() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(pointsCost), 0) FROM redemption WHERE status != 'FAILED'") ?? 0
        }
    }

    private func countForReward(_ rewardID: String) throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM redemption WHERE rewardID = ? AND status != 'FAILED'", arguments: [rewardID]) ?? 0
        }
    }

    // MARK: - Redeem flow (RedemptionEngine.kt's real entry point)

    func redeem(_ reward: RewardCatalogCacheEntry, mobileNumber: String?, network: String?, rewardStore: RewardStore) async throws -> RedemptionOutcome {
        let deviceCount = try countForReward(reward.id)
        if let reason = RedemptionEligibility.checkEligibility(
            isActive: reward.isActive, status: reward.status, startDate: reward.startDate, endDate: reward.endDate,
            stock: reward.stock, redeemedCount: reward.redeemedCount, redemptionLimit: reward.redemptionLimit,
            dailyRedemptionLimit: reward.dailyRedemptionLimit, redeemedToday: reward.redeemedToday,
            userRedemptionLimit: reward.userRedemptionLimit, deviceRedemptionCount: deviceCount
        ) {
            return .rejected(reason: reason)
        }
        if let reason = RedemptionEligibility.validate(
            requiresMobileNumber: reward.requiresMobileNumber, requiresNetwork: reward.requiresNetwork,
            mobileNumber: mobileNumber, network: network
        ) {
            return .rejected(reason: reason)
        }

        let balance = try rewardStore.availableBalance()
        if balance < reward.pointsCost {
            return .rejected(reason: "You need \(reward.pointsCost - balance) more VISION Points.")
        }

        let redemption = Redemption(
            id: UUID().uuidString, rewardID: reward.id, rewardTitle: reward.title, category: reward.category,
            pointsCost: reward.pointsCost, fulfillmentType: reward.fulfillmentType, mobileNumber: mobileNumber,
            network: network, status: .pending, voucherCode: nil, providerReference: nil, failureReason: nil,
            redeemedAt: Date(), fulfilledAt: nil, syncStatus: .pendingUpload
        )
        try dbQueue.write { db in try redemption.insert(db) }

        // Best-effort now; the next real sync() retries regardless of the
        // outcome here — same "local-insert-first" model as Android's own
        // doc comment on RedemptionDbHelper explains.
        await upload(redemption)

        return .submitted
    }

    // MARK: - Remote sync (RewardCatalogRemote.kt + RedemptionUploader.kt + RedemptionSyncWorker.kt, combined)

    private func upload(_ redemption: Redemption) async {
        guard FirebaseConfig.isConfigured(), let idToken = await FirebaseAnonAuth.getValidIDToken(),
              let deviceID = FirebaseAnonAuth.deviceID()
        else { return }

        let fields: [String: Any?] = [
            "deviceId": deviceID, "rewardId": redemption.rewardID, "rewardTitle": redemption.rewardTitle,
            "category": redemption.category, "pointsCost": redemption.pointsCost,
            "fulfillmentType": redemption.fulfillmentType, "mobileNumber": redemption.mobileNumber,
            "network": redemption.network, "status": "PENDING", "voucherCode": nil, "providerReference": nil,
            "failureReason": nil, "redeemedAt": Int64(redemption.redeemedAt.timeIntervalSince1970 * 1000), "fulfilledAt": nil,
        ]
        let result = await FirestoreRestClient.patchDocument("redemptions", redemption.id, fields: fields, idToken: idToken, createOnly: true)
        // A 409 here means this exact real id already exists — a retried
        // upload that actually succeeded last time but didn't get to hear
        // back. That's a real success, not a failure to retry again.
        if result.ok || result.status == 409 {
            try? dbQueue.write { db in
                try db.execute(sql: "UPDATE redemption SET syncStatus = ? WHERE id = ?", arguments: [Redemption.SyncStatus.synced.rawValue, redemption.id])
            }
        }
    }

    private func refreshStatuses() async {
        guard FirebaseConfig.isConfigured(), let idToken = await FirebaseAnonAuth.getValidIDToken(),
              let deviceID = FirebaseAnonAuth.deviceID(),
              let awaitingUpdate = try? dbQueue.read({ db in
                  try Redemption.filter(Column("syncStatus") == Redemption.SyncStatus.synced.rawValue && Column("status") == Redemption.Status.pending.rawValue).fetchAll(db)
              })
        else { return }

        for local in awaitingUpdate {
            let result = await FirestoreRestClient.getDocument("redemptions", local.id, idToken: idToken)
            guard let fields = result.fields, fields["deviceId"] as? String == deviceID, // Never trust a doc that isn't genuinely this device's own.
                  let remoteStatus = fields["status"] as? String, remoteStatus != local.status.rawValue
            else { continue }

            let fulfilledAtMs = fields["fulfilledAt"] as? Int64
            try? dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE redemption SET status = ?, voucherCode = ?, providerReference = ?, failureReason = ?, fulfilledAt = ? WHERE id = ?",
                    arguments: [
                        remoteStatus, fields["voucherCode"] as? String, fields["providerReference"] as? String,
                        fields["failureReason"] as? String,
                        fulfilledAtMs.map { Date(timeIntervalSince1970: Double($0) / 1000) },
                        local.id,
                    ]
                )
            }
        }
    }

    private func pullCatalog() async {
        guard FirebaseConfig.isConfigured(), let idToken = await FirebaseAnonAuth.getValidIDToken() else { return }
        let documents = await FirestoreRestClient.listDocuments("rewardCatalog", idToken: idToken)
        if documents.isEmpty { return } // A real, empty catalog is a valid state — not a failure, and not a reason to wipe a non-empty local cache.

        let entries = documents.compactMap { $0.toCacheEntry() }
        try? dbQueue.write { db in
            try RewardCatalogCacheEntry.deleteAll(db)
            for entry in entries { try entry.insert(db) }
        }
    }

    /// Real, on-demand sync — see this type's own doc comment for why this
    /// isn't a true background job yet. Safe to call opportunistically
    /// (app foreground, screen appear): every real network attempt here
    /// already fails silently and honestly when unreachable, same as
    /// Android's own worker.
    func sync() async {
        guard FirebaseConfig.isConfigured() else { return }
        let pending = (try? dbQueue.read { db in
            try Redemption.filter(Column("syncStatus") == Redemption.SyncStatus.pendingUpload.rawValue).fetchAll(db)
        }) ?? []
        for redemption in pending.prefix(10) { await upload(redemption) }
        await refreshStatuses()
        await pullCatalog()
    }
}

private extension [String: Any?] {
    func toCacheEntry() -> RewardCatalogCacheEntry? {
        guard let name = self["__name"] as? String, let id = name.split(separator: "/").last.map(String.init),
              !id.isEmpty, let title = self["title"] as? String, let pointsCostRaw = self["pointsCost"]
        else { return nil }
        let pointsCost = (pointsCostRaw as? Int64).map(Int.init) ?? (pointsCostRaw as? Int) ?? 0

        func ms(_ key: String) -> Date? {
            guard let raw = self[key] else { return nil }
            let value = (raw as? Int64).map(Double.init) ?? (raw as? Double)
            return value.map { Date(timeIntervalSince1970: $0 / 1000) }
        }
        func intValue(_ key: String) -> Int? {
            guard let raw = self[key] else { return nil }
            return (raw as? Int64).map(Int.init) ?? (raw as? Int)
        }

        return RewardCatalogCacheEntry(
            id: id, title: title, entryDescription: self["description"] as? String ?? "",
            category: self["category"] as? String ?? "lifestyle", rewardType: self["rewardType"] as? String ?? "OTHER",
            pointsCost: pointsCost, currencyValue: self["currencyValue"] as? Double, currency: self["currency"] as? String,
            icon: self["icon"] as? String, fulfillmentType: self["fulfillmentType"] as? String ?? "MANUAL",
            status: self["status"] as? String ?? "PAUSED", stock: intValue("stock"), redemptionLimit: intValue("redemptionLimit"),
            dailyRedemptionLimit: intValue("dailyRedemptionLimit"), userRedemptionLimit: intValue("userRedemptionLimit"),
            startDate: ms("startDate"), endDate: ms("endDate"), terms: self["terms"] as? String,
            instructions: self["instructions"] as? String, isActive: self["isActive"] as? Bool ?? false,
            requiresMobileNumber: self["requiresMobileNumber"] as? Bool ?? false, requiresNetwork: self["requiresNetwork"] as? Bool ?? false,
            redeemedCount: intValue("redeemedCount") ?? 0, redeemedToday: intValue("redeemedToday") ?? 0,
            updatedAt: ms("updatedAt") ?? Date()
        )
    }
}
