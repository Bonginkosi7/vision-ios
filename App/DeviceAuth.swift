import Foundation
import LocalAuthentication

/// Asks for Face ID / Touch ID / the device passcode before a saved password is shown, copied or filled in —
/// the same gate Safari puts in front of its own saved passwords. A phone with no passcode set can't be
/// asked, so it isn't (there is nothing to protect with).
enum DeviceAuth {
    static func authenticate(reason: String) async -> Bool {
        #if DEBUG
        // UI tests can't answer a Face ID prompt.
        if ProcessInfo.processInfo.arguments.contains("-UITestSkipDeviceAuth") { return true }
        #endif
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
