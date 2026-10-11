import Foundation
import GRDB
import WebKit
import Security
import VisionCore

/// "Download my data" and "Delete my data". The rules (what is exported, what is erased) are pure and tested in
/// VisionCore/PrivacyData.swift; this is the part that touches the database, files, Keychain and the network.
enum PrivacyService {
    private static var appSupport: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    // MARK: Download

    /// Writes the person's data to a temporary JSON file and returns it, ready to be shared or saved.
    @MainActor
    static func exportMyData() throws -> URL {
        let tables: [String: [[String: Any]]] = try AppDatabase.shared.read { db in
            var result: [String: [[String: Any]]] = [:]
            for name in try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'") where PrivacyData.shouldExport(table: name) {
                result[name] = try Row.fetchAll(db, sql: "SELECT * FROM \"\(name)\"").map { row in
                    var dict: [String: Any] = [:]
                    for (column, value) in row {
                        switch value.storage {
                        case .null: dict[column] = NSNull()
                        case .int64(let v): dict[column] = v
                        case .double(let v): dict[column] = v
                        case .string(let v): dict[column] = v
                        case .blob: break // never carried into the file
                        }
                    }
                    return dict
                }
            }
            return result
        }
        let defaults = UserDefaults.standard
        let profile: [String: Any] = [
            "name": defaults.string(forKey: ProfileStore.nameKey) ?? "",
            "country": defaults.string(forKey: ProfileStore.countryKey) ?? "",
            "hasPhoto": ProfileStore.shared.photo != nil,
        ]
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let document = PrivacyData.assembleExport(tables: tables, profile: profile, appVersion: version, now: Date())
        let data = try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
        let day = LicenceCore.utcDay(Date())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vision-data-\(day).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Delete

    /// Asks the analytics server to erase what it holds for this installation. True when it did (or had nothing).
    static func requestServerDeletion(installationID: String) async -> Bool {
        if installationID.isEmpty { return true }
        guard AnalyticsConfig.isConfigured(), let url = URL(string: AnalyticsConfig.baseURL + "/v1/data-deletion"),
              let body = try? JSONSerialization.data(withJSONObject: ["installationId": installationID]) else { return false }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AnalyticsConfig.writeKey, forHTTPHeaderField: "x-vision-write-key")
        request.httpBody = body
        guard let (_, response) = try? await URLSession.shared.data(for: request), let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    private static var pendingFile: URL? { appSupport?.appendingPathComponent(PrivacyData.pendingDeletionFile) }

    /// On launch: sends a "delete my data" request that couldn't be sent earlier (no connection at the time).
    static func retryPendingServerDeletion() async {
        guard let file = pendingFile, let data = try? Data(contentsOf: file),
              let id = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["installationId"] as? String else { return }
        if await requestServerDeletion(installationID: id) { try? FileManager.default.removeItem(at: file) }
    }

    /// Erases everything personal on this device: server-side statistics (best effort, retried later if offline),
    /// every row in the database, saved files, settings, Keychain items and the browser's web data.
    @MainActor
    static func deleteMyData() async throws {
        let installationID = AppSettings.analyticsInstallationID ?? ""
        // Remembered first, so if the connection fails the request is sent the next time VISION runs.
        if !installationID.isEmpty, let file = pendingFile {
            try? JSONSerialization.data(withJSONObject: ["installationId": installationID]).write(to: file, options: .atomic)
        }
        if await requestServerDeletion(installationID: installationID), let file = pendingFile { try? FileManager.default.removeItem(at: file) }

        try await AppDatabase.shared.write { db in
            try db.execute(sql: "PRAGMA foreign_keys = OFF")
            let names = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
            for name in PrivacyData.tablesToErase(from: names) { try db.execute(sql: "DELETE FROM \"\(name)\"") }
        }
        if let support = appSupport {
            for entry in PrivacyData.personalFolderEntries { try? FileManager.default.removeItem(at: support.appendingPathComponent(entry)) }
        }
        if let caches = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            try? FileManager.default.removeItem(at: caches.appendingPathComponent("favicons"))
        }
        if let domain = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: domain) }
        // Every Keychain item this app made: saved passwords, AI keys, the licence token.
        SecItemDelete([kSecClass as String: kSecClassGenericPassword] as CFDictionary)
        URLCache.shared.removeAllCachedResponses()
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        await WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
    }
}
