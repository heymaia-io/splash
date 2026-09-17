// swift-tools-version: 6.0
// KomeliaEpubKit — Readium-based EPUB reader (plan Phase 15). Separate package because Readium is iOS-only and
// KomeliaKit must keep building/testing on macOS. Only the iOS app target depends on it.
import PackageDescription

let package = Package(
    name: "KomeliaEpubKit",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "KomeliaEpubKit", targets: ["KomeliaEpubKit"]),
    ],
    dependencies: [
        .package(path: "../KomeliaKit"),
        // BSD-3. Stable 3.x line (4.0 is alpha). Its ZIPFoundation fork is shared with KomeliaKit.
        .package(url: "https://github.com/readium/swift-toolkit.git", exact: "3.11.0"),
    ],
    targets: [
        .target(
            name: "KomeliaEpubKit",
            dependencies: [
                .product(name: "KomeliaUI", package: "KomeliaKit"),
                .product(name: "KomeliaCore", package: "KomeliaKit"),
                .product(name: "KomgaAPI", package: "KomeliaKit"),
                .product(name: "ReadiumShared", package: "swift-toolkit"),
                .product(name: "ReadiumStreamer", package: "swift-toolkit"),
                .product(name: "ReadiumNavigator", package: "swift-toolkit"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]  // Readium 3.x is not Swift 6 clean
        ),
    ]
)
