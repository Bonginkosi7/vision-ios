import Foundation
import GRDB

/// One fact the user told VISION to remember.
struct MemoryEntry: Codable, Identifiable, FetchableRecord, PersistableRecord, Equatable {
    static let databaseTableName = "memoryEntry"
    var id: String
    var text: String
    var createdAt: Date
}

enum MemoryMigrations {
    static func register(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v17_memory") { db in
            try db.create(table: "memoryEntry") { t in
                t.primaryKey("id", .text)
                t.column("text", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
        }
    }
}

/// VISION Memory — port of desktop's MemoryStore.ts and Android's MemoryDbHelper.kt. Only facts the user
/// typed themselves; VISION never infers or writes one on its own. Ask VISION reads them (see ChatAI).
final class MemoryStore: ObservableObject {
    static let shared = MemoryStore()

    private let dbQueue: DatabaseQueue
    @Published private(set) var entries: [MemoryEntry] = []

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
        reload()
    }

    func reload() {
        entries = (try? dbQueue.read { db in try MemoryEntry.order(Column("createdAt")).fetchAll(db) }) ?? []
    }

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = MemoryEntry(id: UUID().uuidString, text: String(trimmed.prefix(300)), createdAt: Date())
        _ = try? dbQueue.write { db in try entry.insert(db) }
        reload()
    }

    func remove(id: String) {
        _ = try? dbQueue.write { db in try MemoryEntry.deleteOne(db, key: id) }
        reload()
    }

    func clearAll() {
        _ = try? dbQueue.write { db in try MemoryEntry.deleteAll(db) }
        reload()
    }

    func facts() -> [String] { entries.map(\.text) }
}
