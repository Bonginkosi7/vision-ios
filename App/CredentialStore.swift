import Foundation
import GRDB
import VisionCore

/// A saved login — metadata only. The password lives in the iOS Keychain, never in the database.
struct SavedCredential: Codable, Identifiable, FetchableRecord, PersistableRecord, Equatable {
    static let databaseTableName = "credential"
    var id: String
    var origin: String
    var username: String
    var createdAt: Date
    var updatedAt: Date
}

enum CredentialMigrations {
    static func register(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v16_credentials") { db in
            try db.create(table: "credential") { t in
                t.primaryKey("id", .text)
                t.column("origin", .text).notNull()
                t.column("username", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "idx_credential_origin", on: "credential", columns: ["origin"])
        }
    }
}

/// Saved passwords — the iOS counterpart of desktop's CredentialStore.ts and Android's CredentialDbHelper.kt.
/// Which site and which username are plain, searchable rows (so Autofill can find a login by origin);
/// each password is its own Keychain item, readable only on this device after it has been unlocked once.
/// Nothing here logs or returns a password except `reveal`.
final class CredentialStore: ObservableObject {
    static let shared = CredentialStore()

    private let dbQueue: DatabaseQueue
    @Published private(set) var credentials: [SavedCredential] = []

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
        reload()
    }

    private static func keychainKey(_ id: String) -> String { "vision.credential.\(id)" }

    func reload() {
        credentials = (try? dbQueue.read { db in
            try SavedCredential.order(Column("origin"), Column("username")).fetchAll(db)
        }) ?? []
    }

    /// Saves a login. The same site + username again replaces that login's password instead of adding a second row.
    @discardableResult
    func save(origin: String, username: String, password: String) throws -> SavedCredential {
        let now = Date()
        let existing = try dbQueue.read { db in
            try SavedCredential.filter(Column("origin") == origin && Column("username") == username).fetchOne(db)
        }
        var record = existing ?? SavedCredential(id: UUID().uuidString, origin: origin, username: username, createdAt: now, updatedAt: now)
        record.updatedAt = now
        KeychainStore.set(password, forKey: Self.keychainKey(record.id))
        try dbQueue.write { db in try record.save(db) }
        reload()
        return record
    }

    func remove(id: String) {
        KeychainStore.delete(forKey: Self.keychainKey(id))
        _ = try? dbQueue.write { db in try SavedCredential.deleteOne(db, key: id) }
        reload()
    }

    /// Logins for exactly this origin — never matched fuzzily or by domain suffix.
    func find(origin: String) -> [SavedCredential] {
        (try? dbQueue.read { db in
            try SavedCredential.filter(Column("origin") == origin).order(Column("username")).fetchAll(db)
        }) ?? []
    }

    func reveal(id: String) -> String? { KeychainStore.get(forKey: Self.keychainKey(id)) }
}
