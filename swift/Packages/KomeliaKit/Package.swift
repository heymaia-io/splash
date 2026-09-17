// swift-tools-version: 6.0
// KomeliaKit — Swift port of the Komelia Kotlin multiplatform modules.
// One local package, one target per Gradle module (see docs/port-map.md for the 1:1 mapping).
import PackageDescription

let package = Package(
    name: "KomeliaKit",
    platforms: [.iOS(.v18), .macOS(.v15)],  // macOS only so `swift test` runs on the host.
    products: [
        .library(name: "KomgaAPI", targets: ["KomgaAPI"]),
        .library(name: "KomgaRemote", targets: ["KomgaRemote"]),
        .library(name: "KomeliaCore", targets: ["KomeliaCore"]),
        .library(name: "KomeliaDB", targets: ["KomeliaDB"]),
        .library(name: "KomeliaOffline", targets: ["KomeliaOffline"]),
        .library(name: "KomeliaImage", targets: ["KomeliaImage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.19"),
    ],
    targets: [
        // komelia-domain/komga-api (+ the wire models of io.github.snd-r:komga-client)
        .target(name: "KomgaAPI"),
        // komelia-domain/core/api/Remote*.kt + komga-client HTTP clients
        .target(name: "KomgaRemote", dependencies: ["KomgaAPI"]),
        // komelia-domain/core (settings, image, color)
        .target(name: "KomeliaCore", dependencies: ["KomgaAPI"]),
        // komelia-domain/offline (domain + repository protocols; storage-agnostic)
        .target(
            name: "KomeliaOffline",
            dependencies: ["KomgaAPI", "KomeliaCore", .product(name: "ZIPFoundation", package: "ZIPFoundation")]),
        // komelia-infra/database — implements the Core/Offline repository protocols (same direction as Gradle)
        .target(
            name: "KomeliaDB",
            dependencies: ["KomeliaCore", "KomeliaOffline", .product(name: "GRDB", package: "GRDB.swift")]),
        // komelia-infra/image-decoder
        .target(name: "KomeliaImage", dependencies: ["KomeliaCore"]),

        .testTarget(name: "KomgaAPITests", dependencies: ["KomgaAPI"], resources: [.copy("Fixtures")]),
        .testTarget(name: "KomgaRemoteTests", dependencies: ["KomgaRemote"]),
        .testTarget(name: "KomeliaCoreTests", dependencies: ["KomeliaCore"]),
        .testTarget(name: "KomeliaDBTests", dependencies: ["KomeliaDB"]),
    ],
    swiftLanguageModes: [.v6]
)
