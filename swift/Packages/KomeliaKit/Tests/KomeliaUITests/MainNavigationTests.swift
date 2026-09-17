import Testing
@testable import KomeliaCore
@testable import KomeliaUI
@testable import KomgaAPI

@MainActor
@Suite struct MainNavigationTests {
    @Test func windowSizeClassThresholds() {
        #expect(WindowSizeClass.from(width: 599) == .compact)
        #expect(WindowSizeClass.from(width: 600) == .medium)
        #expect(WindowSizeClass.from(width: 839) == .medium)
        #expect(WindowSizeClass.from(width: 840) == .expanded)
        #expect(WindowSizeClass.from(width: 1199) == .expanded)
        #expect(WindowSizeClass.from(width: 1200) == .full)
    }

    @Test func navigatorSemantics() {
        let nav = MainNavigator()
        nav.push(.library("L"))
        nav.push(.series("S"))
        #expect(nav.lastItem == .series("S"))
        nav.replace(.book("B"))
        #expect(nav.stack == [.library("L"), .book("B")])
        #expect(nav.popUntil { $0 == .library("L") })
        #expect(nav.stack == [.library("L")])
        nav.replaceAll(.library(nil))
        #expect(nav.root == .library(nil))
        #expect(nav.stack.isEmpty)
        nav.pop()  // no-op on root
        #expect(nav.lastItem == .library(nil))
    }

    @Test func deleteEventsUnwindScreens() {
        let vm = MainScreenViewModel(authState: KomgaAuthenticationState())
        let nav = vm.navigator

        nav.push(.book("B1"))
        vm.handle(.bookDeleted(.init(bookId: "B1", seriesId: "S1", libraryId: "L1")))
        #expect(nav.root == .series("S1") && nav.stack.isEmpty)

        vm.handle(.seriesDeleted(.init(seriesId: "OTHER", libraryId: "L1")))
        #expect(nav.root == .series("S1"))  // fixed precedence bug: other series ignored
        vm.handle(.seriesDeleted(.init(seriesId: "S1", libraryId: "L1")))
        #expect(nav.root == .library("L1"))

        vm.handle(.libraryDeleted(.init(libraryId: "L1")))
        #expect(nav.root == .home)
    }

    @Test func collectionDeletedPopsToLibraryOrHome() {
        let vm = MainScreenViewModel(authState: KomgaAuthenticationState())
        let nav = vm.navigator
        nav.replaceAll(.library("L"))
        nav.push(.collection("C"))
        vm.handle(.collectionDeleted(try! JSONDecoderHelper.collection("C")))
        #expect(nav.lastItem == .library("L"))

        nav.replaceAll(.collection("C"))
        vm.handle(.collectionDeleted(try! JSONDecoderHelper.collection("C")))
        #expect(nav.root == .home)
    }

    @Test func taskQueueStatusIsTracked() {
        let vm = MainScreenViewModel(authState: KomgaAuthenticationState())
        vm.handle(KomgaEvent.decode(event: "TaskQueueStatus", data: #"{"count":3,"countByType":{"ScanLibrary":3}}"#))
        #expect(vm.taskQueueStatus?.count == 3)
    }
}

enum JSONDecoderHelper {
    static func collection(_ id: String) throws -> KomgaEvent.CollectionPayload {
        try KomgaJSON.makeDecoder().decode(
            KomgaEvent.CollectionPayload.self, from: Data(#"{"collectionId":"\#(id)","seriesIds":[]}"#.utf8))
    }
}

import Foundation
