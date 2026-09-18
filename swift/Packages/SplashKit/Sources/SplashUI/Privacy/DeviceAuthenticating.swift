import Foundation
import LocalAuthentication

/// Device-owner authentication, behind a protocol so the private area can be tested.
///
/// `LAContext` cannot be exercised in the package's macOS `swift test` run, so every test substitutes a
/// fake. This is the only seam that matters for the privacy feature's correctness tests — the order of
/// authenticate/entitlement/unlock is what they assert.
@MainActor
public protocol DeviceAuthenticating: AnyObject {
    /// False when the device has no passcode set, in which case there is nothing to protect the area with.
    func canAuthenticate() -> Bool
    func authenticate(reason: String) async -> Bool
}

@MainActor
public final class LocalDeviceAuthenticator: DeviceAuthenticating {
    public init() {}

    public func canAuthenticate() -> Bool {
        // A fresh context per call: a reused one can satisfy a later check from an earlier success.
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    public func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        // `.deviceOwnerAuthentication`, not `…WithBiometrics`: the device passcode is then the automatic
        // fallback when Face ID fails, is not enrolled, or is locked out.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
