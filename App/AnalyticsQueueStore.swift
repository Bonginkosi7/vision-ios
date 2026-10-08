import Foundation
import GRDB

/// Real local queue for analytics events/crashes — direct GRDB port of
/// AnalyticsQueueDbHelper.kt (itself a port of desktop's
/// AnalyticsQueueStore.ts). VISION runs offline often, so analytics can't
/// assume a live connection either here: events queue in this real local
/// database and are uploaded once connectivity returns
/// (AnalyticsClient.flush()). This is local storage with the same
/// protection as the rest of VISION's local data (OS file permissions on
/// the user's own device), not additional encryption on top of it —
/// documented here rather than implied, matching Android/desktop's own
/// honesty about this exact point.
public struct QueuedAnalyticsEvent: Codable, Identifiable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "analyticsQueue"
    public var id: String
    public var eventName: String
    public var properties: String // JSON-encoded, same real shape as the other two ports' TEXT column.
    public var clientTimestamp: Int64
    public var createdAt: Date
}

public struct QueuedCrash: Codable, Identifiable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "crashQueue"
    public var id: String
    public var component: String?
    public var errorType: String?
    public var stackTrace: String?
    public var clientTimestamp: Int64
    public var createdAt: Date
}

/// GRDB migrations for the two tables above — a new migration added to
/// AppDatabase's own shared migrator (see AppDatabase.swift), matching this
/// repo's own established "one shared .sqlite file, each feature owns its
/// migration step" convention (RedemptionMigrations is the same pattern).
enum AnalyticsMigrations {
    static func register(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v15_analytics") { db in
            try db.create(table: "analyticsQueue") { t in
                t.primaryKey("id", .text)
                t.column("eventName", .text).notNull()
                t.column("properties", .text).notNull()
                t.column("clientTimestamp", .integer).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_analyticsQueue_createdAt", on: "analyticsQueue", columns: ["createdAt"])

            try db.create(table: "crashQueue") { t in
                t.primaryKey("id", .text)
                t.column("component", .text)
                t.column("errorType", .text)
                t.column("stackTrace", .text)
                t.column("clientTimestamp", .integer).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_crashQueue_createdAt", on: "crashQueue", columns: ["createdAt"])
        }
    }
}

/// Same real bounds as AnalyticsQueueDbHelper.kt/AnalyticsQueueStore.ts —
/// once over the cap, the oldest queued rows are dropped first: they're
/// the least useful for a "how many people are using VISION right now"
/// question anyway.
private let maxEventQueueSize = 2000
private let maxCrashQueueSize = 500

final class AnalyticsQueueStore {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared) {
        self.dbQueue = dbQueue
    }

    func enqueueEvent(id: String, eventName: String, properties: [String: Any], clientTimestamp: Int64) async {
        let propertiesJSON = Self.encodeProperties(properties)
        let event = QueuedAnalyticsEvent(id: id, eventName: eventName, properties: propertiesJSON, clientTimestamp: clientTimestamp, createdAt: Date())
        try? await dbQueue.write { db in
            try event.insert(db)
            let overflow = try QueuedAnalyticsEvent.fetchCount(db) - maxEventQueueSize
            if overflow > 0 {
                try db.execute(sql: "DELETE FROM analyticsQueue WHERE id IN (SELECT id FROM analyticsQueue ORDER BY createdAt ASC LIMIT ?)", arguments: [overflow])
            }
        }
    }

    func dequeueEventBatch(limit: Int) async -> [QueuedAnalyticsEvent] {
        (try? await dbQueue.read { db in
            try QueuedAnalyticsEvent.order(Column("createdAt").asc).limit(limit).fetchAll(db)
        }) ?? []
    }

    func removeEvents(_ ids: [String]) async {
        guard !ids.isEmpty else { return }
        try? await dbQueue.write { db in
            _ = try QueuedAnalyticsEvent.deleteAll(db, keys: ids)
        }
    }

    // --- Crashes: a separate, smaller queue so a flood of ordinary usage
    // events can never crowd out crash diagnostics or vice versa — same
    // split as the other two ports. ---

    func enqueueCrash(id: String, component: String?, errorType: String?, stackTrace: String?, clientTimestamp: Int64) async {
        let crash = QueuedCrash(id: id, component: component, errorType: errorType, stackTrace: stackTrace, clientTimestamp: clientTimestamp, createdAt: Date())
        try? await dbQueue.write { db in
            try crash.insert(db)
            let overflow = try QueuedCrash.fetchCount(db) - maxCrashQueueSize
            if overflow > 0 {
                try db.execute(sql: "DELETE FROM crashQueue WHERE id IN (SELECT id FROM crashQueue ORDER BY createdAt ASC LIMIT ?)", arguments: [overflow])
            }
        }
    }

    func dequeueCrashBatch(limit: Int) async -> [QueuedCrash] {
        (try? await dbQueue.read { db in
            try QueuedCrash.order(Column("createdAt").asc).limit(limit).fetchAll(db)
        }) ?? []
    }

    func removeCrashes(_ ids: [String]) async {
        guard !ids.isEmpty else { return }
        try? await dbQueue.write { db in
            _ = try QueuedCrash.deleteAll(db, keys: ids)
        }
    }

    private static func encodeProperties(_ properties: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: properties) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func decodeProperties(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return object
    }
}
