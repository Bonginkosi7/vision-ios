import Foundation

/// "Download my data" and "Delete my data" rules, as pure data and functions so they can be tested.
public enum PrivacyData {
    // MARK: Download

    public static let exportFormat = "vision-data-export"

    /// Tables that are never exported: queues of statistics waiting to be sent, and the public reward catalogue.
    public static let excludedTables: Set<String> = ["analyticsQueue", "crashQueue", "rewardCatalogCache", "grdb_migrations"]

    /// Columns left out of the export: where a saved page or document lives on disk, and a document's full extracted text.
    public static let excludedColumns: Set<String> = ["contentPath", "extractedText"]

    public static func shouldExport(table: String) -> Bool {
        !excludedTables.contains(table) && !table.hasPrefix("sqlite_")
    }

    /// The export file: every table's rows (minus the excluded columns), a header and a note. Saved passwords are
    /// not in the database at all (they live in the Keychain), so they can't appear here.
    public static func assembleExport(tables: [String: [[String: Any]]], profile: [String: Any], appVersion: String, now: Date) -> [String: Any] {
        var cleaned: [String: Any] = [:]
        for (name, rows) in tables where shouldExport(table: name) {
            cleaned[name] = rows.map { $0.filter { !excludedColumns.contains($0.key) } }
        }
        return [
            "format": exportFormat,
            "formatVersion": 1,
            "exportedAt": ISO8601DateFormatter().string(from: now),
            "appVersion": appVersion,
            "note": "Saved passwords are not included, only the site and username. Saved pages are not included, only their titles and addresses.",
            "profile": profile,
            "data": cleaned,
        ]
    }

    // MARK: Delete

    /// Everything VISION keeps in its Application Support folder that belongs to the person.
    public static let personalFolderEntries = ["OfflineLibrary", "Downloads", "StudyDocuments", "favicons", "profile-photo.jpg"]

    /// Kept on purpose: downloaded AI models aren't personal, and the retry marker for a server deletion must survive the erase.
    public static let keptEntries = ["local-models", "pending-server-deletion.json"]

    public static let pendingDeletionFile = "pending-server-deletion.json"

    /// Tables to empty when erasing: all of them except SQLite's own and the migration record (the schema stays).
    public static func tablesToErase(from all: [String]) -> [String] {
        all.filter { !$0.hasPrefix("sqlite_") && $0 != "grdb_migrations" }
    }
}
