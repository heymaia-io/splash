import Foundation
import SwiftUI
import Testing
@testable import KomgaAPI
@testable import SplashCore
@testable import SplashUI

@MainActor
final class FakeDeviceAuthenticator: DeviceAuthenticating {
    var available: Bool
    var succeeds: Bool
    private(set) var attempts = 0
    private(set) var lastReason: String?

    init(available: Bool = true, succeeds: Bool = true) {
        self.available = available
        self.succeeds = succeeds
    }

    func canAuthenticate() -> Bool { available }

    func authenticate(reason: String) async -> Bool {
        attempts += 1
        lastReason = reason
        return succeeds
    }
}

@MainActor
final class FakeAccessPolicy: PremiumAccessPolicy {
    var isUnlocked: Bool
    private(set) var requestedContexts: [String] = []

    init(isUnlocked: Bool) { self.isUnlocked = isUnlocked }

    func requestUnlock(for context: PaywallContext) { requestedContexts.append(context.id) }
}

@MainActor
@Suite struct PrivacyControllerTests {
    private func make(
        authAvailable: Bool = true, authSucceeds: Bool = true, purchased: Bool = true,
        hidden: HiddenContent = HiddenContent(), clock: @escaping @MainActor () -> Date = { Date() }
    ) async throws -> (PrivacyController, FakeDeviceAuthenticator, FakeAccessPolicy) {
        let repository = try await SettingsState.load(
            from: InMemorySettingsStore<HiddenContent>(hidden), default: hidden)
        var app = AppSettings()
        app.serverUrl = "http://komga.test"
        let settings = try await SettingsState.load(from: InMemorySettingsStore<AppSettings>(app), default: app)
        let auth = FakeDeviceAuthenticator(available: authAvailable, succeeds: authSucceeds)
        let access = FakeAccessPolicy(isUnlocked: purchased)
        let controller = PrivacyController(
            repository: repository, settings: settings, auth: auth, access: access, now: clock)
        return (controller, auth, access)
    }

    // MARK: Reveal — order of operations is the security story

    @Test func successfulAuthWithPurchaseUnlocks() async throws {
        let (controller, auth, access) = try await make()
        await controller.requestReveal()
        #expect(controller.isUnlocked)
        #expect(auth.attempts == 1)
        #expect(access.requestedContexts.isEmpty)
    }

    @Test func failedAuthStaysLockedAndNeverShowsThePaywall() async throws {
        // The paywall would confirm the feature exists to someone who found the gesture by accident.
        let (controller, auth, access) = try await make(authSucceeds: false, purchased: false)
        await controller.requestReveal()
        #expect(!controller.isUnlocked)
        #expect(auth.attempts == 1)
        #expect(access.requestedContexts.isEmpty)
    }

    @Test func authenticatedButUnpurchasedShowsThePrivacyPaywall() async throws {
        let (controller, _, access) = try await make(purchased: false)
        await controller.requestReveal()
        #expect(!controller.isUnlocked)
        #expect(access.requestedContexts == ["privacy"])
    }

    @Test func noDevicePasscodeNeverPrompts() async throws {
        let (controller, auth, access) = try await make(authAvailable: false)
        await controller.requestReveal()
        #expect(!controller.isUnlocked)
        #expect(auth.attempts == 0)
        #expect(access.requestedContexts.isEmpty)
    }

    // MARK: Re-lock policies

    @Test func onLeavingLocksOnBackgroundButNotOnInactive() async throws {
        let (controller, _, _) = try await make()
        await controller.setLockPolicy(.onLeaving)
        await controller.requestReveal()

        // `.inactive` fires during the auth prompt, Control Centre and the app switcher.
        controller.scenePhaseChanged(.inactive)
        #expect(controller.isUnlocked)

        controller.scenePhaseChanged(.background)
        #expect(!controller.isUnlocked)
    }

    @Test func afterTimeoutLocksOnlyOnceTheDelayHasPassed() async throws {
        var clock = Date(timeIntervalSince1970: 1_000)
        let (controller, _, _) = try await make(clock: { clock })
        await controller.setLockPolicy(.afterTimeout)
        await controller.setLockTimeout(60)
        await controller.requestReveal()

        controller.scenePhaseChanged(.background)
        clock = clock.addingTimeInterval(30)
        controller.scenePhaseChanged(.active)
        #expect(controller.isUnlocked)

        controller.scenePhaseChanged(.background)
        clock = clock.addingTimeInterval(61)
        controller.scenePhaseChanged(.active)
        #expect(!controller.isUnlocked)
    }

    @Test func untilAppQuitsSurvivesEveryPhaseChange() async throws {
        let (controller, _, _) = try await make()
        await controller.setLockPolicy(.untilAppQuits)
        await controller.requestReveal()
        controller.scenePhaseChanged(.inactive)
        controller.scenePhaseChanged(.background)
        controller.scenePhaseChanged(.active)
        #expect(controller.isUnlocked)
    }

    // MARK: Hiding

    @Test func hidingWritesThroughAndStampsTheServer() async throws {
        let (controller, _, _) = try await make()
        await controller.setHidden(true, seriesId: KomgaSeriesId("s1"))
        await controller.setHidden(true, libraryId: KomgaLibraryId("lib-a"))
        #expect(controller.isHidden(seriesId: KomgaSeriesId("s1")))
        #expect(controller.isHidden(libraryId: KomgaLibraryId("lib-a")))
        #expect(controller.hidden.serverUrl == "http://komga.test")

        await controller.setHidden(false, seriesId: KomgaSeriesId("s1"))
        #expect(!controller.isHidden(seriesId: KomgaSeriesId("s1")))
    }

    /// The whole of round 3 in one assertion: unlocking means "stop filtering", decided in exactly one
    /// place. Before this, `filter()` ignored `isUnlocked` and hidden downloads stayed invisible even
    /// while the rest of the app was revealed.
    @Test func filterStopsFilteringOnceUnlocked() async throws {
        var content = HiddenContent()
        content.series = [KomgaSeriesId("s1")]
        let (controller, _, _) = try await make(hidden: content)

        #expect(controller.filter().hidden.series == [KomgaSeriesId("s1")])
        await controller.requestReveal()
        #expect(controller.isUnlocked)
        #expect(controller.filter().isNoop)
        #expect(controller.filter().hidden.series.isEmpty)

        controller.lock()
        #expect(controller.filter().hidden.series == [KomgaSeriesId("s1")])
    }

    /// The filter every *screen* uses comes from `ViewModelFactory`, not from the controller directly.
    /// When the factory held its own copy of the rule it knew what was hidden but not that the area had
    /// been unlocked, so unlocking revealed nothing anywhere. This asserts the two cannot drift again.
    @Test func theFactoryFilterTracksTheController() async throws {
        var content = HiddenContent()
        content.libraries = [KomgaLibraryId("lib-a")]
        let (controller, _, _) = try await make(hidden: content)

        let factory = ViewModelFactory(
            apiProvider: { fatalError("unused") },
            settings: SettingsState(initial: AppSettings(), save: { _ in }),
            imageReaderSettings: SettingsState(initial: ImageReaderSettings(), save: { _ in }),
            homeFilters: SettingsState(initial: [], save: { _ in }),
            authState: KomgaAuthenticationState(),
            events: KomgaEventBroadcaster(),
            thumbnails: nil,
            hiddenFilter: { controller.filter() })

        #expect(factory.hiddenFilter()().isHidden(libraryId: KomgaLibraryId("lib-a")))
        await controller.requestReveal()
        #expect(!factory.hiddenFilter()().isHidden(libraryId: KomgaLibraryId("lib-a")))
    }

    @Test func filterIsDisabledWhenTheHiddenSetBelongsToAnotherServer() async throws {
        var other = HiddenContent()
        other.serverUrl = "http://somewhere.else"
        other.series = [KomgaSeriesId("s1")]
        let (controller, _, _) = try await make(hidden: other)

        // Komga ids are per-server; applying them across servers could hide unrelated content.
        #expect(controller.filter().isNoop)
        #expect(controller.filter().hidden.series.isEmpty)
    }
}
