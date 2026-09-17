# Splash

Splash is a native iOS client for [Komga](https://github.com/gotson/komga), the self-hosted comic, manga and
ebook server. It is a Swift/SwiftUI port of [Komelia](https://github.com/Snd-R/Komelia), the Kotlin
Multiplatform Komga client, rebuilt around Apple frameworks and extended with full offline reading.

Splash is an unofficial, independent client and is not affiliated with or endorsed by the Komga project.

## Features

- **Library browsing** — home, libraries, series, one-shots, collections, read lists and search.
- **Readers** — paged (spreads, right-to-left, scale types, page transitions) and continuous/webtoon for
  images, [Readium](https://github.com/readium/swift-toolkit) for EPUB and PDFKit-backed vector rendering
  for PDF.
- **Offline mode** — books are downloaded through a background `URLSession`, verified with XXH3, stored
  locally and served by an offline implementation of the same Komga API protocols, so every screen works
  unchanged without a server. Read progress and metadata edits are queued and synced back when online.
- **Live updates** — the server's SSE stream drives incremental refreshes of open screens and thumbnail
  invalidation.
- **Adaptive UI** — single column on iPhone, split view on iPad, with keyboard shortcuts.
- **No telemetry** — the app collects no user data. See `PRIVACY_POLICY.MD` in the upstream Komelia
  repository for the policy this project inherits.

## Repository layout

| Path | Contents |
|---|---|
| `swift/Splash.xcodeproj`, `swift/Splash/` | iOS app target (iOS 18+) and its resources |
| `swift/Packages/SplashKit` | Main local SPM package — one target per upstream Gradle module |
| `swift/Packages/SplashEpubKit` | Readium-based EPUB reader; separate package because Readium is iOS-only |
| `swift/Config` | `Info.plist`, StoreKit configuration |
| `docs/port-map.md` | 1:1 mapping from Komelia's Kotlin symbols to their Swift counterparts, plus the deliberate deviations |
| `docs/wire-format.md` | The Komga wire contract (107 operations) the client is built against |
| `fixtures/komga` | Dockerized Komga instance with deterministic seed data, used by the contract tests |
| `tools/wire_contract_check.py` | Checks the client's requests against `fixtures/komga/openapi.json` |
| `graphify-out/` | Knowledge graph of the repository (see `CLAUDE.md`) |

`SplashKit` targets, in dependency order:

```
KomgaAPI        models, identifiers, search conditions, API protocols (no networking)
KomgaRemote     HTTP clients, cookie/API-key auth, SSE session
SplashCore      settings, auth/secrets, image and color types
SplashOffline   offline domain model, download and sync engines, action queue
SplashDB        GRDB persistence implementing the Core/Offline repository protocols
SplashImage     ImageIO/Core Graphics decoding pipeline
SplashUI        SwiftUI screens and view models (depends only on protocols)
SplashAppShared composition root (AppModule)
```

The dependency direction is enforced by `Package.swift`: UI and domain code never see a concrete API or
database type, only the protocols in `KomgaAPI`, `SplashCore` and `SplashOffline`.

## Requirements

- Xcode 16 or later (Swift 6 toolchain)
- iOS 18+ device or simulator
- macOS 15+ to run the package tests on the host
- Docker, for the fixture server used by the contract tests

## Building

Open `swift/Splash.xcodeproj` in Xcode and run the `Splash` scheme, or build from the command line:

```sh
xcodebuild -project swift/Splash.xcodeproj -scheme Splash \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Testing

`SplashKit` builds for macOS so its tests run on the host without a simulator:

```sh
cd swift/Packages/SplashKit
swift test
```

The contract tests in `KomgaRemoteTests` need the fixture server:

```sh
cd fixtures/komga
./setup.sh          # generate CBZs, start the container, seed data, dump openapi.json
docker compose down # stop; data persists in ./data (gitignored)
```

The fixture server listens on `http://localhost:25601` with the credentials documented in
`fixtures/komga/README.md`.

## Attribution and licensing

Splash is licensed under the Apache License 2.0 — see [`LICENSE`](LICENSE).

It is a derivative work of [Komelia](https://github.com/Snd-R/Komelia) (Apache 2.0) and of
[komga-client](https://github.com/Snd-R/komga-client) (MIT), both by Snd-R. The original Kotlin source was
translated to Swift and modified; [`NOTICE`](NOTICE) records the attributions and the bundled third-party
licenses, which are also shown in the app under Settings › Third-party licenses.
