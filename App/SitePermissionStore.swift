import Foundation
import GRDB
import VisionCore

/// One remembered answer to "may this site use your camera / microphone?".
struct SitePermission: Codable, Identifiable, FetchableRecord, PersistableRecord, Equatable {
    static let databaseTableName = "sitePermission"
    var origin: String
    var permission: String
    var granted: Bool
    var updatedAt: Date

    var id: String { "\(origin)|\(permission)" }
    var kind: SitePermissionKind? { SitePermissionKind(rawValue: permission) }
}

enum SitePermissionMigrations {
    static func register(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v19_site_permissions") { db in
            try db.create(table: "sitePermission") { t in
                t.column("origin", .text).notNull()
                t.column("permission", .text).notNull()
                t.column("granted", .boolean).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.primaryKey(["origin", "permission"])
            }
        }
    }
}

/// Remembered per-site permission decisions for what a page asks the app about (camera, microphone) — the iOS
/// counterpart of desktop's PermissionStore and Android's PermissionDbHelper. "Never asked" (nil) is genuinely
/// different from a remembered "block".
final class SitePermissionStore: ObservableObject {
    static let shared = SitePermissionStore()

    private let dbQueue: DatabaseQueue
    @Published private(set) var permissions: [SitePermission] = []

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
        reload()
    }

    func reload() {
        permissions = (try? dbQueue.read { db in
            try SitePermission.order(Column("origin"), Column("permission")).fetchAll(db)
        }) ?? []
    }

    func get(origin: String, kind: SitePermissionKind) -> Bool? {
        try? dbQueue.read { db in
            try SitePermission.filter(Column("origin") == origin && Column("permission") == kind.rawValue).fetchOne(db)?.granted
        }
    }

    func set(origin: String, kind: SitePermissionKind, granted: Bool) {
        try? dbQueue.write { db in
            try SitePermission(origin: origin, permission: kind.rawValue, granted: granted, updatedAt: Date()).save(db)
        }
        publishChange()
    }

    func remove(_ permission: SitePermission) {
        _ = try? dbQueue.write { db in
            try SitePermission.filter(Column("origin") == permission.origin && Column("permission") == permission.permission).deleteAll(db)
        }
        publishChange()
    }

    func removeAll() {
        _ = try? dbQueue.write { db in try SitePermission.deleteAll(db) }
        publishChange()
    }

    private func publishChange() {
        if Thread.isMainThread { reload() } else { DispatchQueue.main.async { self.reload() } }
    }
}
