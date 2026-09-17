// swift-tools-version: 6.0
// SplashKit — Swift port of the Komelia Kotlin multiplatform modules.
// One local package, one target per Gradle module (see docs/port-map.md for the 1:1 mapping).
import PackageDescription

let package = Package(
    name: "SplashKit",
    platforms: [.iOS(.v18), .macOS(.v15)],  // macOS only so `swift test` runs on the host.
    products: [
        .library(name: "KomgaAPI", targets: ["KomgaAPI"]),
        .library(name: "KomgaRemote", targets: ["KomgaRemote"]),
        .library(name: "SplashCore", targets: ["SplashCore"]),
        .library(name: "SplashDB", targets: ["SplashDB"]),
        .library(name: "SplashOffline", targets: ["SplashOffline"]),
        .library(name: "SplashImage", targets: ["SplashImage"]),
        .library(name: "SplashUI", targets: ["SplashUI"]),
        .library(name: "SplashAppShared", targets: ["SplashAppShared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
        // Readium's ZIPFoundation fork (same package identity as upstream; Readium requires it).
        .package(url: "https://github.com/readium/ZIPFoundation.git", from: "3.0.1"),
    ],
    targets: [
        // komelia-domain/komga-api (+ the wire models of io.github.snd-r:komga-client)
        .target(name: "KomgaAPI"),
        // komelia-domain/core/api/Remote*.kt + komga-client HTTP clients
        .target(name: "KomgaRemote", dependencies: ["KomgaAPI"]),
        // komelia-domain/core (settings, image, color)
        .target(name: "SplashCore", dependencies: ["KomgaAPI"]),
        // komelia-domain/offline (domain + repository protocols; storage-agnostic)
        .target(
            name: "SplashOffline",
            dependencies: ["KomgaAPI", "SplashCore", .product(name: "ReadiumZIPFoundation", package: "ZIPFoundation")]),
        // komelia-infra/database — implements the Core/Offline repository protocols (same direction as Gradle)
        .target(
            name: "SplashDB",
            dependencies: [
                "KomgaAPI", "SplashCore", "SplashOffline", .product(name: "GRDB", package: "GRDB.swift"),
            ]),
        // komelia-infra/image-decoder
        .target(name: "SplashImage", dependencies: ["KomgaAPI", "SplashCore"]),

        // komelia-ui — SwiftUI screens + view models (depends only on protocols, never on concrete APIs)
        .target(
            name: "SplashUI",
            dependencies: ["KomgaAPI", "SplashCore", "SplashImage", "SplashOffline"],
            resources: [.process("Resources")]),
        // komelia-app/shared — composition root (AppModule)
        .target(
            name: "SplashAppShared",
            dependencies: ["SplashUI", "KomgaRemote", "SplashCore", "SplashDB", "SplashOffline", "SplashImage"]),

        .testTarget(name: "KomgaAPITests", dependencies: ["KomgaAPI"], resources: [.copy("Fixtures")]),
        .testTarget(name: "KomgaRemoteTests", dependencies: ["KomgaRemote"]),
        .testTarget(name: "SplashCoreTests", dependencies: ["SplashCore"]),
        .testTarget(name: "SplashDBTests", dependencies: ["SplashDB"]),
        .testTarget(name: "SplashUITests", dependencies: ["SplashUI", "KomgaRemote"]),
        .testTarget(
            name: "SplashOfflineTests",
            dependencies: ["SplashOffline", "SplashDB", "KomgaRemote"],
            resources: [.copy("Fixtures")]),
        .testTarget(name: "SplashImageTests", dependencies: ["SplashImage"]),
    ],
    swiftLanguageModes: [.v6]
)
