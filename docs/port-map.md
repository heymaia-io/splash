# Port map — Komelia (Kotlin) → Komelia iOS (Swift)

Tracks the plan in `~/.claude/plans/harmonic-seeking-conway.md`. Kotlin locations were resolved with
`graphify explain "<Symbol>"` (root graph); Swift locations with
`graphify explain "<Symbol>" --graph swift/graphify-out/graph.json` (regenerate with `graphify update swift --no-cluster`).

## Layout

| Swift | Kotlin origin |
|---|---|
| `swift/Komelia.xcodeproj` + `swift/Komelia/` (app target, iOS 18) | `komelia-app`, `komelia-ui` |
| `swift/Packages/KomeliaKit` — target `KomgaAPI` | `komelia-domain/komga-api` + models of `io.github.snd-r:komga-client:0.11.0` |
| target `KomgaRemote` | `komelia-domain/core/api/Remote*.kt`, `core/http/*`, komga-client `Http*Client` |
| target `KomeliaCore` | `komelia-domain/core` (settings, image, color) |
| target `KomeliaDB` | `komelia-infra/database` |
| target `KomeliaOffline` | `komelia-domain/offline` |
| target `KomeliaImage` | `komelia-infra/image-decoder` |

One local SPM package with one target per Gradle module (instead of 7 packages) — same boundaries, less
Xcode wiring. Dependency direction is enforced by `Package.swift`.

## Phase status

| Phase | Status | Notes |
|---|---|---|
| F0 foundations + wire contract | ✅ | Package + app build; fixture server (`fixtures/komga`); `docs/wire-format.md` (107 ops, all in OpenAPI) |
| F1 KomgaAPI + RemoteAPI | ✅ | 12 protocols, models, search conditions, SSE catalog; 34 tests incl. live contract tests |
| F2 auth / secrets / session | ✅ | Keychain secrets, ApiKeyStore, LoginViewModel/LoginView, session restore (offline login → F10) |
| F3 persistence (GRDB) | ✅ | komelia.sqlite + offline.sqlite (33/33 tables), stores, records, task queue |
| F4 adaptive shell | ✅ | MainNavigator, WindowSizeClass, MainShellView (split view on iPad) |
| F5 thumbnails | ✅ | ThumbnailLoader + ThumbnailView |
| F6 library screens | ✅ | Home, Library, Series, Book, Oneshot, Collection, ReadList, Search (no filter editor) |
| F7 SSE + live updates | 🟡 | LiveEventsController fan-out, scenePhase pause, thumbnail invalidation, per-screen reloads; needs on-device verification |
| F8 image engine | ⬜ | |
| F9 reader | ⬜ | |
| F10 offline API | ⬜ | `OfflineBookStateProvider` seam already consumed by remote APIs |
| F11 downloads | ⬜ | `RemoteBookApi.bookFileRequest` seam ready; server has no Range support |
| F12 sync | ⬜ | |
| F13 polish | ⬜ | |

## Symbol map

| Kotlin | Swift | Status |
|---|---|---|
| `KomgaApi` (komga-api/KomgaApi.kt) | `KomgaApi` (KomgaAPI/Protocols/KomgaApi.swift) | ✅ |
| `KomgaBookApi` … `KomgaUserApi` (12 interfaces) | same names, `async throws` | ✅ |
| `KomeliaBook` | `KomeliaBook` (composition + `@dynamicMemberLookup`) | ✅ |
| `KomgaSort` / `KomgaBooksSort` / `KomgaSeriesSort` / `KomgaUserSort` | `KomgaSort` + factory enums | ✅ |
| `KomgaPageRequest`, `Page<T>` | same | ✅ |
| `KomgaSearchCondition.*`, `KomgaSearchOperator.*` | `BookCondition`, `SeriesCondition`, `EqualityOp`… | ✅ |
| `ConditionBuilder` DSL | `.allOfBooks(...)` / `.anyOfSeries(...)` helpers | ✅ |
| `PatchValue` + `UpdateValueSerializer` | `PatchValue` + `KeyedEncodingContainer.encode` overload | ✅ |
| `KomgaEvent` + `toKomgaEvent` | `KomgaEvent` + `KomgaEvent.decode` (lookup table) | ✅ |
| `KomgaSSESession`, `RemoteApi.CombinedSSESession` | `KomgaSSESession`, `RemoteSSESession` | ✅ |
| `MutableSharedFlow<KomgaEvent>` (offline events) | `KomgaEventBroadcaster` | ✅ |
| `RemoteApi` | `RemoteKomgaApi` | ✅ |
| `RemoteBookApi` (+ `getKomeliaBook(Page)`) | `RemoteBookApi` + `OfflineBookStateProvider` | ✅ |
| `RemoteSeriesApi`, `RemoteLibraryApi`, `RemoteCollectionsApi`, `RemoteReadListApi`, `RemoteReferentialApi`, `RemoteUserApi`, `RemoteSettingsApi`, `RemoteTaskApi`, `RemoteActuatorApi`, `RemoteAnnouncementsApi`, `RemoteFileSystemApi` | same names | ✅ |
| `KomgaClientFactory.configureKtor` | `KomgaHTTPClient` | ✅ |
| `RememberMePersistingCookieStore` | `KomgaCookieStore` + `KomgaCookiePersistence` | ✅ (Keychain impl in F2) |
| `ApiKeyStore` | `ApiKeyStore` (KomeliaCore/Auth) | ✅ |
| `SecretsRepository` | `SecretsRepository` + `KeychainSecretsRepository` | ✅ |
| `SettingsStateWrapper` / `*RepositoryWrapper` | `SettingsState<T>` | ✅ |
| `LoginViewModel`, `MainScreenViewModel`, `HomeViewModel`, `LibraryViewModel`, `SeriesViewModel`, `BookViewModel` … | same names (KomeliaUI) | ✅ |
| `KomeliaFetcherFactory` (Coil) | `ThumbnailRequest` + `ThumbnailLoader` | ✅ |
| `AppModule` | `AppModule` (KomeliaAppShared) | ✅ |

## Deliberate deviations (documented, not silent)

- Kotlin `Page.page()` computes `first`/`last` inverted → fixed in `Page.page(content:request:total:)`.
- Multiple sort orders were concatenated into one `sort` value → one `sort` param per order.
- Collection/read-list author filter used `authors=` (ignored by server) → `author=name,role` repeated.
- List query params always joined with `,` (Kotlin mixed `", "` and `","`).
- EPUB/Readium models ported for protocol completeness only (EPUB reader deferred to v1.1).
- Deprecated GET listing endpoints (`getAllSeries`, `getAllBooksBySeries`) not ported — Komelia's facade doesn't expose them.
