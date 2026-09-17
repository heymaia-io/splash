# CLAUDE.md

This file is auto-derived from a [graphify](https://github.com/safishamsi/graphify) knowledge graph of this
repository (`graphify-out/graph.json`, `graphify-out/GRAPH_REPORT.md`), not from a manual code read. Regenerate
with `/graphify --update` after significant changes, and re-run this doc's generation if the module map below
goes stale.

## What this is

**Komelia** — a self-hosted manga/comic (and ebook) reader client, built as a Kotlin Multiplatform app targeting
Android, Desktop (JVM), and Web (Wasm/JS), talking to a [Komga](https://github.com/gotson/komga) media server
backend. It also ships a browser extension (`komelia-komf-extension`) that integrates with **Komf** (a
Komga metadata-fetching companion tool), and bundles two forked web-based ebook readers
(`komga-webui`, `ttu-ebook-reader`) for EPUB support.

Root project lives under `kotlin/` (Gradle multi-module + a native CMake superbuild for image decoding,
ONNX inference, and WebView embedding).

## Module map (Gradle `include()`s, cross-referenced with graph communities)

| Module | Role |
|---|---|
| `komelia-app:androidApp` / `desktopApp` / `webApp` / `shared` | Per-platform app entry points + shared app-level DI (`AppRepositories`, `CoreModule`, `AndroidAppModule`/`DesktopAppModule`/`WasmAppModule`) |
| `komelia-domain:core` | Core domain: settings repositories, image processing (`KomeliaImage`, upscaling, color correction), Coil integration |
| `komelia-domain:offline` | Offline mode: local mirrors of Komga entities (`OfflineBook`, `OfflineSeries`), sync actions (`OfflineAction`/`OfflineActions` framework), metadata patch capabilities |
| `komelia-domain:komga-api` | Komga REST client (`RemoteReferentialApi`, `RemoteLibraryApi`, `KomgaSeriesId`/`KomgaBookId` etc.) |
| `komelia-ui` | Compose Multiplatform UI: reader screens (paged/continuous), book/series screens, settings dialogs, bulk actions, filters, Komf settings tabs |
| `komelia-infra:database:{transaction,shared,sqlite,wasm}` | Persistence layer — Exposed/SQLite on JVM/Android, no-op/IndexedDB-backed repos on Wasm |
| `komelia-infra:image-decoder:{shared,vips,wasm-image-worker}` | Native image decoding via libvips (JNI) and a Wasm worker actor (`CanvasImageActor`) |
| `komelia-infra:jni` | Shared JNI native bindings |
| `komelia-infra:onnxruntime:{api,jvm}` | ONNX Runtime execution providers (CPU/CUDA/ROCm/DirectML/TensorRT/WebGPU) for ML-based upscaling/panel detection |
| `komelia-infra:webview` | Native WebView embedding (WebView2 on Windows, WebKit2GTK on Linux) used to host the epub readers |
| `komelia-komf-extension:{app,content,background,popup,shared}` | Browser extension integrating with Komf for metadata jobs |
| `komelia-epub-reader/komga-webui`, `komelia-epub-reader/ttu-ebook-reader` | Vendored/forked web EPUB readers (Vue + Svelte), hosted in-app via the native WebView module |
| `third_party/*` | Vendored deps: ChipTextField, compose-sonner, secret-service (composite build) |

Native build: root `kotlin/CMakeLists.txt` runs an `ExternalProject_Add` superbuild chain —
`ep_vips → ep_komelia_vips`, `ep_onnxruntime → ep_komelia_onnxruntime` (depends on vips), `ep_glib → ep_komelia_webview`
(skipped on Android). Each native module also has its own standalone CMakeLists for JNI shared libs, with
per-vendor GPU device-enumeration libs (CUDA/ROCm/Vulkan/DXGI) gated by CMake options.

## Core domain model (god nodes — most cross-referenced entities)

From the graph's centrality analysis, these are the entities everything else hangs off of — touch them carefully:

1. `KomeliaBook` (124 edges) — central book model, referenced across reader, offline, bulk-actions, and screen communities
2. `KomgaSeries` (101 edges) — central series model, same cross-cutting pattern
3. `Op` (84 edges)
4. `KomeliaImage` (69 edges) — image processing pipeline core type
5. `ViewModelFactory` (59 edges)
6. `ImageReaderSettingsRepository` (58 edges)
7. `StateHolder` (55 edges)
8. `DialogTab` (51 edges)
9. `DropdownChoiceMenu()` (50 edges)
10. `ReaderSettingsRepositoryWrapper` (49 edges)

`KomeliaBook` and `KomgaSeries` have the highest betweenness centrality in the whole graph (0.186 and 0.100) —
they are the bridge nodes between almost every feature area (reader, offline, bulk actions, home/library
screens, Komf integration). Treat changes to their shape as cross-cutting.

## Known structural notes (from graph diagnostics)

- **Import cycle**: `komelia-epub-reader/komga-webui/src/App.vue → EpubReader.vue → main.ts → App.vue` (3-file cycle in the vendored webui).
- **Low-cohesion clusters** flagged by community detection as candidates for splitting if touched again:
  `Book Filter Conditions` (cohesion 0.05), `Image Upscaling Settings` (0.03), `Epub Reader (Vue)` (0.03).
- **740 weakly-connected/isolated nodes**, mostly native build config symbols (`PKG_CONFIG_DIR`, `PKG_CONFIG_LIBDIR`, etc.) —
  expected for build-system tokens, not a code smell.
- Two vendored web readers (`komga-webui`, `ttu-ebook-reader`) are forks of upstream `gotson/komga` and
  `ttu-ttu/ebook-reader` respectively — check upstream before making non-trivial changes there.

## Privacy

`PRIVACY_POLICY.MD` states the app collects no user data at all — there is intentionally no telemetry/analytics
opt-out mechanism beyond uninstalling.

## Working with the graph

- `graphify query "<question>"` — ask the graph directly instead of grepping (BFS/DFS traversal over `graph.json`)
- `graphify path "A" "B"` — shortest path between two concepts/entities
- `graphify explain "SomeSymbol"` — plain-language explanation of a node
- `/graphify --update` — re-run after code changes to keep the graph (and this map) current
