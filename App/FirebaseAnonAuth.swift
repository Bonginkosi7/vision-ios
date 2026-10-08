import Foundation

/// Real per-install Firebase Anonymous Auth identity for the shared rewards
/// backend — direct port of FirebaseAnonAuth.kt. This device's one real,
/// stable-until-reinstall identity, used to own its own redemption
/// requests under Firestore's real security rules (firestore.rules in the
/// desktop repo: a redemption's `deviceId` field must equal
/// `request.auth.uid`, exactly this value). A Firebase client API key
/// isn't secret by design (real security comes from those rules, keyed on
/// real auth), so no extra encryption of the key itself is needed — but
/// the refresh token this mints IS a real credential worth protecting, so
/// it's stored the same way this app's own AI API keys are
/// (KeychainStore, the real iOS counterpart of Android's
/// EncryptedSharedPreferences).
enum FirebaseAnonAuth {
    private static let keyUID = "vision_firebase_uid"
    private static let keyRefreshToken = "vision_firebase_refresh_token"
    private static let requestTimeout: TimeInterval = 10
    private static let refreshSafetyMargin: TimeInterval = 60

    private static var cachedIDToken: String?
    private static var cachedIDTokenExpiresAt: Date = .distantPast

    /// This device's real, stable Firebase uid — nil until a real identity
    /// has been minted at least once.
    static func deviceID() -> String? {
        KeychainStore.get(forKey: keyUID)
    }

    /// Returns a real, currently-valid ID token — minting a real anonymous
    /// identity on first use, refreshing on later calls once the cached
    /// one is near expiry. Returns nil if unconfigured or every real
    /// network attempt fails; never fabricates a token.
    static func getValidIDToken() async -> String? {
        guard FirebaseConfig.isConfigured() else { return nil }
        if let cachedIDToken, Date() < cachedIDTokenExpiresAt.addingTimeInterval(-refreshSafetyMargin) {
            return cachedIDToken
        }
        if let storedRefreshToken = KeychainStore.get(forKey: keyRefreshToken),
           let token = await refresh(storedRefreshToken) {
            return token
        }
        return await mint()
    }

    private static func mint() async -> String? {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(FirebaseConfig.apiKey)") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["returnSecureToken": true])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
              let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uid = body["localId"] as? String,
              let refreshToken = body["refreshToken"] as? String,
              let idToken = body["idToken"] as? String
        else { return nil }

        KeychainStore.set(uid, forKey: keyUID)
        KeychainStore.set(refreshToken, forKey: keyRefreshToken)
        cacheIDToken(idToken, expiresIn: body["expiresIn"] as? String)
        return cachedIDToken
    }

    private static func refresh(_ refreshToken: String) async -> String? {
        guard let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(FirebaseConfig.apiKey)") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=refresh_token&refresh_token=\(refreshToken)".data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
              let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newRefreshToken = body["refresh_token"] as? String,
              let idToken = body["id_token"] as? String
        else { return nil }

        // Firebase rotates the refresh token on every real refresh — the
        // stored one must be updated, or the next refresh fails with a
        // stale token.
        KeychainStore.set(newRefreshToken, forKey: keyRefreshToken)
        cacheIDToken(idToken, expiresIn: body["expires_in"] as? String)
        return cachedIDToken
    }

    private static func cacheIDToken(_ idToken: String, expiresIn: String?) {
        cachedIDToken = idToken
        let seconds = expiresIn.flatMap { Double($0) } ?? 3600
        cachedIDTokenExpiresAt = Date().addingTimeInterval(seconds)
    }
}
