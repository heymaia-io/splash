import Foundation
import LocalAuthentication

/// Seam over `LAContext`, which cannot run under `swift test` — there is no device owner to authenticate as,
/// so `PrivacyControllerTests` substitutes a fake.
@MainActor
public protocol DeviceAuthenticating: Sendable {
    /// False when the device has no passcode set, which makes the whole feature unavailable.
    func canAuthenticate() -> Bool
    func authenticate(reason: String) async -> Bool
}

/// Face ID / Touch ID with the system passcode as fallback.
public struct LocalDeviceAuthenticator: DeviceAuthenticating {
    public init() {}

    /// `.deviceOwnerAuthentication`, **not** `…WithBiometrics`: the passcode is then the automatic fallback
    /// when biometry is unavailable, unenrolled, or locked out after failed attempts.
    private static let policy: LAPolicy = .deviceOwnerAuthentication

    /// A **fresh context per call**. Reusing one lets an earlier successful evaluation satisfy a later check
    /// within `touchIDAuthenticationAllowableReuseDuration`, so the second reveal would not actually prompt.
    private func context() -> LAContext { LAContext() }

    public func canAuthenticate() -> Bool {
        var error: NSError?
        let can = context().canEvaluatePolicy(Self.policy, error: &error)
        // `passcodeNotSet` means the feature is simply unavailable. Do not fall back to an app-level PIN:
        // it would be weaker than this honest refusal, and it would be the thing an attacker attacks.
        return can
    }

    public func authenticate(reason: String) async -> Bool {
        let context = context()
        guard context.canEvaluatePolicy(Self.policy, error: nil) else { return false }
        return (try? await context.evaluatePolicy(Self.policy, localizedReason: reason)) ?? false
    }
}
