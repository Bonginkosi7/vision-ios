import Foundation
import VisionCore

/// Real Firestore REST calls — direct port of FirestoreRestClient.kt, same
/// reasoning: plain `URLSession` + `FirestoreValueCodec` (VisionCore,
/// real-verified without Xcode) rather than pulling in the full Firestore
/// SDK for what's really just typed JSON over HTTPS. Same two real
/// collections the real security rules (firestore.rules, desktop repo)
/// and every other real client (Android, desktop) use: `rewardCatalog`
/// and `redemptions` — never invented ad hoc per caller.
enum FirestoreRestClient {
    struct FirestoreResult {
        let ok: Bool
        let status: Int
        let fields: [String: Any?]?
    }

    private static let requestTimeout: TimeInterval = 10

    private static func baseURL() -> String {
        "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectID)/databases/(default)/documents"
    }

    static func getDocument(_ collectionPath: String, _ docID: String, idToken: String) async -> FirestoreResult {
        guard let url = URL(string: "\(baseURL())/\(collectionPath)/\(docID)") else {
            return FirestoreResult(ok: false, status: -1, fields: nil)
        }
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        return await readResult(request)
    }

    /// Every real document in a collection, decoded. Firestore's REST
    /// `listDocuments` response nests each document under `"documents"` —
    /// an empty/missing collection is a real, valid state (an honest empty
    /// array), never an error.
    static func listDocuments(_ collectionPath: String, idToken: String) async -> [[String: Any?]] {
        guard let url = URL(string: "\(baseURL())/\(collectionPath)") else { return [] }
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
              let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = body["documents"] as? [[String: Any]]
        else { return [] }

        return documents.map { doc in
            var fields = FirestoreValueCodec.decodeFields(doc["fields"] as? [String: Any])
            // The real document id lives in its resource `name`
            // ("projects/.../documents/rewardCatalog/<id>"), not in
            // `fields` — carried through under a reserved key no real
            // Firestore field ever uses, same convention
            // RewardCatalogRemote.kt's own `__name` key establishes.
            fields["__name"] = doc["name"] as? String
            return fields
        }
    }

    /// Create-or-overwrite a document. `createOnly: true` adds Firestore's
    /// own `currentDocument.exists=false` precondition — the atomic
    /// "create exactly once" guarantee a retried redemption upload after a
    /// partial failure depends on (see RedemptionStore.swift).
    static func patchDocument(_ collectionPath: String, _ docID: String, fields: [String: Any?], idToken: String, createOnly: Bool = false) async -> FirestoreResult {
        let query = createOnly ? "?currentDocument.exists=false" : ""
        guard let url = URL(string: "\(baseURL())/\(collectionPath)/\(docID)\(query)") else {
            return FirestoreResult(ok: false, status: -1, fields: nil)
        }
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        // Sent as a real PATCH directly — unlike Android's own documented
        // HttpURLConnection workaround (X-HTTP-Method-Override via a POST,
        // needed because stock Android rejects "PATCH" as an invalid
        // method on many OS versions), URLSession has no such restriction.
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["fields": FirestoreValueCodec.encodeFields(fields)]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return await readResult(request)
    }

    static func deleteDocument(_ collectionPath: String, _ docID: String, idToken: String) async -> FirestoreResult {
        guard let url = URL(string: "\(baseURL())/\(collectionPath)/\(docID)") else {
            return FirestoreResult(ok: false, status: -1, fields: nil)
        }
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        return await readResult(request)
    }

    private static func readResult(_ request: URLRequest) async -> FirestoreResult {
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse
        else { return FirestoreResult(ok: false, status: -1, fields: nil) }

        let ok = (200...299).contains(httpResponse.statusCode)
        guard ok, let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return FirestoreResult(ok: ok, status: httpResponse.statusCode, fields: nil)
        }
        let fields = FirestoreValueCodec.decodeFields(body["fields"] as? [String: Any])
        return FirestoreResult(ok: true, status: httpResponse.statusCode, fields: fields)
    }
}
