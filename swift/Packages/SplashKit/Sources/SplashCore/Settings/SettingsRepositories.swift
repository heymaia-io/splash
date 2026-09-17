import Foundation

/// `CommonSettingsRepository` — Kotlin exposes one Flow getter + suspend setter per field; Swift exposes
/// the whole state (`SettingsState<AppSettings>`) plus key-path projections, which covers the same surface.
public typealias CommonSettingsRepository = SettingsState<AppSettings>

/// `ImageReaderSettingsRepository` (22 keys in Kotlin; ONNX keys dropped).
public typealias ImageReaderSettingsRepository = SettingsState<ImageReaderSettings>

extension SettingsState where Value == AppSettings {
    public var serverURL: URL? { URL(string: value.serverUrl) }
}

/// Port of `snd.komelia.settings.SecretsRepository` (6 methods, keyed by server URL).
public protocol SecretsRepository: Sendable {
    func getCookie(url: String) async throws -> String?
    func setCookie(url: String, cookie: String) async throws
    func deleteCookie(url: String) async throws
    func getApiKey(url: String) async throws -> String?
    func setApiKey(url: String, apiKey: String) async throws
    func deleteApiKey(url: String) async throws
}
