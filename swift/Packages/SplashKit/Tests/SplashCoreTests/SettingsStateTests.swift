import Testing
@testable import SplashCore

@Suite struct SettingsStateTests {
    @Test func loadsDefaultPersistsAndPublishesDistinctProjections() async throws {
        let store = InMemorySettingsStore<AppSettings>()
        let settings = try await SettingsState.load(from: store, default: AppSettings())
        #expect(try await store.load() == AppSettings())

        let urls = settings.values(\.serverUrl)
        var iterator = urls.makeAsyncIterator()
        // A fresh install has no server yet; the login form shows its placeholder instead of a guess.
        #expect(await iterator.next() == "")

        try await settings.set(\.cardWidth, 200)  // different field: no url emission
        try await settings.set(\.serverUrl, "https://komga.example")
        #expect(await iterator.next() == "https://komga.example")
        #expect(try await store.load()?.cardWidth == 200)
    }

    @Test func failedSaveDoesNotPublish() async throws {
        struct Boom: Error {}
        let settings = SettingsState(initial: AppSettings()) { _ in throw Boom() }
        await #expect(throws: Boom.self) { try await settings.set(\.cardWidth, 1) }
        #expect(settings.value.cardWidth == 170)
    }
}
