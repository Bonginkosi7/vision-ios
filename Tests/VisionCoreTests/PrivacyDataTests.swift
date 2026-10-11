import XCTest
@testable import VisionCore

final class PrivacyDataTests: XCTestCase {
    func testExportLeavesOutQueuesCataloguesPathsAndExtractedText() {
        let doc = PrivacyData.assembleExport(
            tables: [
                "bookmark": [["id": 1, "title": "A", "url": "https://a.com"]],
                "studyDocument": [["id": "d", "title": "Notes", "contentPath": "/private/x", "extractedText": "BIG TEXT"]],
                "analyticsQueue": [["eventName": "app_opened"]],
                "rewardCatalogCache": [["id": "r"]],
                "credential": [["id": "c", "origin": "https://a.com", "username": "ann"]],
            ],
            profile: ["name": "Ann"], appVersion: "0.1.0", now: Date(timeIntervalSince1970: 1_791_763_140)
        )
        XCTAssertEqual(doc["format"] as? String, PrivacyData.exportFormat)
        XCTAssertEqual(doc["exportedAt"] as? String, "2026-10-11T23:59:00Z")
        let data = doc["data"] as! [String: Any]
        XCTAssertNil(data["analyticsQueue"])
        XCTAssertNil(data["rewardCatalogCache"])
        XCTAssertNotNil(data["bookmark"])
        let study = (data["studyDocument"] as! [[String: Any]])[0]
        XCTAssertNil(study["contentPath"])
        XCTAssertNil(study["extractedText"])
        XCTAssertEqual(study["title"] as? String, "Notes")
        let json = String(data: try! JSONSerialization.data(withJSONObject: doc), encoding: .utf8)!
        XCTAssertFalse(json.contains("BIG TEXT"))
        let dataJSON = String(data: try! JSONSerialization.data(withJSONObject: data), encoding: .utf8)!
        XCTAssertFalse(dataJSON.lowercased().contains("password"))
        XCTAssertTrue(json.contains("\"username\":\"ann\""))
    }

    func testEveryPersonalFolderIsErasedAndModelsAndTheRetryMarkerAreKept() {
        XCTAssertTrue(PrivacyData.personalFolderEntries.contains("OfflineLibrary"))
        XCTAssertTrue(PrivacyData.personalFolderEntries.contains("StudyDocuments"))
        XCTAssertTrue(PrivacyData.personalFolderEntries.contains("profile-photo.jpg"))
        XCTAssertTrue(Set(PrivacyData.personalFolderEntries).isDisjoint(with: PrivacyData.keptEntries))
        XCTAssertTrue(PrivacyData.keptEntries.contains(PrivacyData.pendingDeletionFile))
    }

    func testErasingEmptiesEveryTableButKeepsSQLitesOwnAndTheMigrationRecord() {
        XCTAssertEqual(PrivacyData.tablesToErase(from: ["bookmark", "sqlite_sequence", "grdb_migrations", "task"]), ["bookmark", "task"])
    }

    func testThePrivacyWordingCoversTheThreeSectionsAndSaysWhatDeletingDoesNotCover() {
        XCTAssertEqual(PrivacyContent.sections.map(\.id), ["stays", "leaves", "never"])
        for section in PrivacyContent.sections {
            XCTAssertFalse(section.items.isEmpty)
            for item in section.items { XCTAssertGreaterThan(item.text.count, 20) }
        }
        XCTAssertTrue(PrivacyContent.Rights.deleteLimits.contains("hello@ann-connect.com"))
        XCTAssertTrue(PrivacyContent.Rights.deleteLimits.contains("redeemed"))
    }
}
