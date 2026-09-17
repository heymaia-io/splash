// swift-tools-version: 6.0
// SplashEpubKit — Readium-based EPUB reader (plan Phase 15). Separate package because Readium is iOS-only and
// SplashKit must keep building/testing on macOS. Only the iOS app target depends on it.
import PackageDescription

let package = Package(
    name: "SplashEpubKit",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "SplashEpubKit", targets: ["SplashEpubKit"]),
    ],
    dependencies: [
        .package(path: "../SplashKit"),
        // BSD-3. Stable 3.x line (4.0 is alpha). Its ZIPFoundation fork is shared with SplashKit.
        .package(url: "https://github.com/readium/swift-toolkit.git", exact: "3.11.0"),
    ],
    targets: [
        .target(
            name: "SplashEpubKit",
            dependencies: [
                .product(name: "SplashUI", package: "SplashKit"),
                .product(name: "SplashCore", package: "SplashKit"),
                .product(name: "KomgaAPI", package: "SplashKit"),
                .product(name: "ReadiumShared", package: "swift-toolkit"),
                .product(name: "ReadiumStreamer", package: "swift-toolkit"),
                .product(name: "ReadiumNavigator", package: "swift-toolkit"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]  // Readium 3.x is not Swift 6 clean
        ),
    ]
)
