# Splash — private (hidden) content

**Implementation brief.** Read it end to end before writing any code.

This feature was built three times and thrown away three times. The design below is what survived.
[Do not build](#7-do-not-build) is not advice — every item in it was implemented, shipped, and deleted,
and rebuilding any of them reintroduces a bug that is named there.

---

## 1. What to build

Let the user mark a whole **library**, a whole **series**, or a single **book** as private.

While **locked**, private content is absent from every listing: Home shelves, Library, global search,
series book lists, collections, read lists, the Downloads shelf, in-flight download rows, and the admin
screens in Settings.

While **unlocked**, the filter simply stops applying. Private content reappears wherever Komga puts it,
exactly as if the feature did not exist. There is no separate screen, no separate tab, no parallel
navigation.

Unlocking requires device authentication (Face ID / Touch ID / passcode) and is reached only through a
deliberate hidden gesture. The feature is gated behind the existing one-time in-app purchase.

Komga has no concept of private content. This is entirely client-side; nothing about it is ever sent to
the server.

---

## 2. Non-negotiable design decisions

### 2.1 One source of truth for "should I filter?"

`PrivacyController.filter()` is the only place that decides. It returns `.disabled` when unlocked, and
the real filter otherwise.

`ViewModelFactory` must **not** compute its own. It receives the provider from the composition root:

```swift
hiddenFilter: { [unowned self] in self.privacy?.filter() ?? .disabled }
```

**Why.** A previous version gave the factory its own copy of the rule. That copy knew what was hidden but
not that the area had been unlocked, so unlocking revealed nothing anywhere while Settings and Downloads
behaved correctly. A second copy of this rule is the single most likely bug in this feature.

### 2.2 Hidden ids are keyed by server

```swift
struct PrivacyState {
    var lockPolicy: PrivacyLockPolicy
    var lockTimeout: TimeInterval
    var byServer: [String: HiddenContent]   // key = AppSettings.serverUrl
}
```

A Komga id only means anything on the server that issued it.

**Why not a single set plus a `serverUrl` stamp.** Every write rewrote the stamp, so hiding something
after switching servers silently re-labelled the previous server's ids as belonging to the new one, and
switching back left the whole original set inert — silent loss of the user's privacy settings. Making
the server the *key* removes the failure mode instead of guarding against it.

Lock preferences stay top-level; they are a device preference.

### 2.3 Unlocking is "stop filtering", not "show somewhere else"

There is exactly one filtering direction. Do not add a mode enum.

### 2.4 Filtering lives in view models, not in an API decorator

A `KomgaApi` decorator would need ~120 forwarding stubs (`KomgaBookApi` ~57, `KomgaSeriesApi` ~47,
`KomgaLibraryApi` ~18). View-model filtering also means the offline `KomgaApi` implementation is covered
for free.

### 2.5 Server conditions are an optimisation; `visible(_:)` is the guard

Komga **can** express:

- exclude by library id, on series and book queries
- exclude by series id, on **book** queries only

Komga **cannot** express:

- exclude a series by id from a *series* query — `SeriesCondition` has no id case
- exclude a book by id from a *book* query — `BookCondition` has no id case

So every call site pushes conditions where they exist **and** always runs `filter.visible(...)` over the
result. Never rely on the condition alone.

---

## 3. Architecture

### `SplashCore/Privacy/HiddenContent.swift`

| Type | Purpose |
|---|---|
| `HiddenContent` | `libraries` / `series` / `books` sets for **one** server |
| `PrivacyState` | `lockPolicy`, `lockTimeout`, `byServer` |
| `PrivacyLockPolicy` | `onLeaving` · `afterTimeout` · `untilAppQuits` |

### `SplashCore/Privacy/HiddenContentFilter.swift`

Pure value type. All the reasoning lives here so each call site is one line that review can verify by eye.

```swift
isHidden(libraryId:/series:/book:)     // inheritance resolved here
visible(_ libraries/series/books)
seriesConditions / bookConditions      // server-side, optimisation only
libraryAllowList(from:) -> [KomgaLibraryId]?
```

`libraryAllowList` returns `nil` when nothing is excluded, so the request stays byte-identical for users
who never hide anything.

**Inheritance:** hiding a library hides its series and books; hiding a series hides its books.
`KomgaSeries` carries `libraryId` and `SplashBook` carries both, so this is decidable locally with no
extra fetches.

### `SplashDB`

`GRDBPrivacyStore` — JSON blob in a `version = 1` row, modelled on `GRDBHomeScreenFilterStore`. New
migration appended to `AppMigrations` (never edit `v1_initial`); add the table name to
`AppMigrations.tableNames` **and** to the literal set asserted in `MigrationTests`.

> **Careful:** `load()` turns a decode failure into `nil`, which makes defaults get re-saved — i.e. a bad
> decode *erases* the user's hidden set. Keep that in mind for any future shape change.

### `SplashUI/Privacy/`

- **`DeviceAuthenticating`** — protocol seam; `LAContext` cannot run in `swift test`.
- **`LocalDeviceAuthenticator`** — uses `.deviceOwnerAuthentication` (**not** `…WithBiometrics`) so the
  passcode is the automatic fallback, with a **fresh `LAContext` per call** — reusing one lets a previous
  unlock satisfy a later check. `canEvaluatePolicy` failing with `passcodeNotSet` means the feature is
  simply unavailable; do **not** build an app-level PIN fallback, which would be weaker than the honest
  refusal.
- **`PrivacyController`** — `@MainActor @Observable`:
  - `isUnlocked` — **memory only**, never persisted, so process death re-locks
  - `hidden: HiddenContent { state.content(for: settings.value.serverUrl) }`
  - `filter()`, `isHidden(...)`, `setHidden(...)`, `lock()`, `requestReveal()`, `scenePhaseChanged(_:)`
- `PrivacyRevealGesture`, `PrivacyBanner`, `PrivacyBlur`, `HideMenuButton`, `PrivacySettingsView`,
  `PrivateCatalogViewModel`

**Environment:** `\.privacy`, set in `AppRootView` next to `\.offlineController`. `AppSession` gains
`var privacy: PrivacyController?` (optional, like `entitlements`).

---

## 4. Filter chokepoints — all of them

One forgotten listing defeats the whole feature.

| Site | What to do |
|---|---|
| `HomeScreen` | `HomeViewModel.fetch` — 5 branches. Conditions on the two custom ones, `libraryIds` allow-list on the three that take no condition, then `visible(...)` on every result. Needs `authState` injected for the library list |
| `LibraryScreen` | `loadSeriesPage` (append `seriesConditions` + `visible`); `loadCollections` / `loadReadLists` / `loadItemCounts` (allow-list when `libraryId == nil`); `LibraryViewModel.libraries` → `filter.visible(authState.libraries)` |
| `SearchScreen` | conditions on both queries + `visible` on both results |
| `SeriesScreen` | `loadBooks` — `bookConditions` is exact here, so paging stays right |
| `BookScreen` | `OneshotViewModel` — refuse to render a hidden item |
| `CollectionScreens` | collection + read-list view models — client-side `visible(...)` |
| `AppModule` | `downloadedSeries()` — covers the Downloads tab **and** the offline fallback shelf |
| `DownloadViews` | `activeTransfers` + the settings download list — a transfer row carries the book title |
| `SettingsView` | `ServerSettingsView` (shows library **name and filesystem path**), `AccountSettingsView.libraryAccess` (resolves ids to names), `MediaAnalysisView` (server-wide book list with full paths) |

**Do not filter:** `UsersView`, `AuthenticationActivityView`, `AnnouncementsView` — no library data.

View models take the filter as a **provider**, not a snapshot, and subscribe to the repository so hiding
something refreshes the screen live. Skip the first emission: `SettingsState.values()` replays the
current value and `initialize()` already loaded.

The shell must rebuild when `isUnlocked` flips — it writes nothing to the repository, so those
subscriptions do not fire. Key the `NavigationStack` on both the navigator root and the unlock state.

---

## 5. Reveal, re-lock, and exposure

### Gesture

Long press (1.5 s) on the dead trailing space beside the "All Libraries" chip on the Library screen.

- Do **not** attach it to the `Menu` label — it fights the menu's own press-and-hold.
- Do **not** try to attach it to the large navigation title: SwiftUI has no supported way to gesture the
  title from `.navigationTitle(_:)`, and `.principal` is occupied by the tab picker.

### Order of operations in `requestReveal()`

Authenticate **before** checking the purchase:

1. `canAuthenticate()` else return silently
2. authenticate, with `isAuthenticating` set around the call
3. failure → **return silently**. No alert, no toast, no haptic. Any differentiated response is an oracle
   telling a snooper the feature exists
4. no entitlement → `requestUnlock(for: .privacy)`
5. unlock; success haptic

### Re-lock

`scenePhase` reaches `.inactive` during the Face ID prompt itself, Control Centre, notification banners
and the app switcher. **Never lock on `.inactive`.**

| Policy | Behaviour |
|---|---|
| `.onLeaving` | lock on `.background` |
| `.afterTimeout` | evaluate elapsed time on return to `.active`, not on a timer — a suspended app would miss it |
| `.untilAppQuits` | nothing; `isUnlocked` is memory-only |

Guard all of it with `isAuthenticating` — the passcode fallback can background the app on some
configurations. On lock, reset the navigator to Home and clear the search query: being deep inside
content that is about to vanish must eject you.

### Exposure

Unlocked content sits in the ordinary UI, so:

- **`PrivacyBanner`** — "Private content visible" + *Lock now*, beside `OfflineBanner`
- **Lock badge** on hidden cards, *composed* with the existing unread count and download glyph in
  `ItemCard`'s overlay slot, not replacing them
- **`PrivacyBlur`** over the window while `.inactive` and unlocked, or the app-switcher snapshot leaks
  everything the feature hides
- **Settings → Private** — a real list with per-row Unhide. It is the only way to see what is hidden.
  Render the row **only** while unlocked
- **Settings → About** — tap the version row 7× to reveal a help page documenting the gesture. Needed for
  App Review (guideline 2.3.1 treats hidden functionality as grounds for rejection) and for the user who
  forgets

### Hide actions

The ellipsis menus on Series and Book; Library needs a new one. All gated on `isUnlocked` so they are
invisible otherwise. For a downloaded book offer **"Hide and delete download"** — filtering hides it from
the shelf, not from the filesystem.

### Deep link

`AppRootView.open(_:)` bypasses every listing. Guard it.

### Info.plist

Add `INFOPLIST_KEY_NSFaceIDUsageDescription` to **both** the Debug and Release blocks of
`project.pbxproj` (this project declares usage strings as build settings). Missing it in either config is
a hard crash on first evaluation. Keep the wording neutral — it appears in Settings → Face ID & Passcode.

---

## 6. Entitlement

One product gates both offline reading and privacy, so the types are named `Premium*`
(`PremiumAccessPolicy`, `PremiumEntitlementStore`, `PremiumStoreProvider`, `PremiumProductInfo`,
`PremiumProduct`).

**Do not change the product id.** It stays `"com.heymaia.splash.offline"` — it is registered in App Store
Connect and changing it orphans every existing purchase. Comment this, or the mismatch will look like a
bug.

`PaywallView` takes a `PaywallContext` (icon, title, subtitle, benefits) with `.offline` and `.privacy`
presets. Both must say the one purchase unlocks both, or two paywalls for one SKU reads as a dark pattern
at review.

**Debug bypass:** `SPLASH_UNLOCK_PREMIUM=1` swaps in `AlwaysUnlockedPolicy`. It bypasses the *purchase*,
not the *lock* — the gesture and Face ID are still required.

---

## 7. Do not build

Each of these was built and deleted.

- **A "Private" tab, or any parallel screen showing hidden content.** It needs by-id resolution, a
  client-side re-implementation of every Home shelf's query, and a two-half search — ~775 lines carrying
  four bugs.
- **`HiddenContentMode` / an `.onlyHidden` inverse filter.** Every hard limit in the feature came from
  this, not from hiding.
- **A client-side evaluator of `HomeScreenFilter` conditions.** It only interpreted the operators the
  *default* shelves use. Customise a home filter with a tag condition and hidden items silently stopped
  appearing — wrong behaviour with no error.
- **A second copy of the "should I filter?" rule, anywhere.** See [2.1](#21-one-source-of-truth-for-should-i-filter).
- **A `serverUrl` stamp on a single flat set.** See [2.2](#22-hidden-ids-are-keyed-by-server).
- **An app-level PIN when the device has no passcode.** See [§3](#3-architecture).
- **Over-fetching or page-splicing to fix the pagination count.** See [§8](#8-known-limits--document-do-not-fix).

---

## 8. Known limits — document, do not "fix"

- Individually hidden **series** cannot be excluded server-side, so a library page can render up to *k*
  fewer cards than the page size and the total is corrected only approximately. Keep the server's
  `totalPages` — shrinking it makes the tail unreachable. Over-fetching grows linearly with page depth;
  splicing needs a cursor `KomgaPageRequest` cannot express. The real fix is upstream in Komga.
- Downloaded files of hidden books stay readable on disk.
- The hidden-id list is **plaintext** in `splash.sqlite`. Someone with a filesystem backup sees *which*
  ids are hidden, not their contents. This is obscurity behind a biometric gate, not encryption — never
  market it as a "vault" or "secure".
- The thumbnail cache retains hidden covers.
- Hiding is device-local; the Komga web UI and every other client show everything.
- No device passcode → no feature.

---

## 9. Sequencing

Each step is independently mergeable. The feature stays inert until step 6, because an empty hidden set
makes every filter a no-op.

1. Model + GRDB store + migration + DB tests
2. `HiddenContentFilter` + unit tests — the bulk of the test value
3. `Premium*` rename + `PaywallContext`
4. `DeviceAuthenticating` + `PrivacyController` + Info.plist keys + tests
5. Filter wiring at every chokepoint in [§4](#4-filter-chokepoints--all-of-them)
6. Reveal gesture, hide menus, banner, badge, blur, Settings → Private, help page — **the feature goes
   live here**
7. Sweep: deep-link guard, offline-mode pass, downloads

---

## 10. Verification

### Unit

swift-testing; follow `EntitlementTests.swift` for the `Mutex` / `AsyncStream` fakes.

- **`HiddenContentFilter`** — inheritance in all three directions; conditions encode to the right wire
  shape; `libraryAllowList` returns `nil` when nothing is hidden.
- **`PrivacyState`** — decodes its own round-trip; per-server isolation.
- **`PrivacyController`**, with a `FakeDeviceAuthenticator` and an injected clock:
  - failed auth leaves it locked **and does not present the paywall**
  - auth-without-entitlement presents the `.privacy` paywall
  - no passcode never calls `authenticate`
  - `.onLeaving` locks on `.background` but **not** on `.inactive`
  - `.afterTimeout` respects the clock; `.untilAppQuits` never locks
  - `isAuthenticating` suppresses the background lock
  - `filter()` returns `.disabled` while unlocked — *regression test for [2.1](#21-one-source-of-truth-for-should-i-filter)*
  - the `ViewModelFactory` filter tracks the controller — *regression test for [2.1](#21-one-source-of-truth-for-should-i-filter)*
- **Switching servers** — hide on A, switch to B → nothing hidden; hide on B → A is untouched; switch
  back → A is intact. *Regression test for [2.2](#22-hidden-ids-are-keyed-by-server).*

Not worth writing: view-model tests against a stub `KomgaApi` (~120 methods). Keep the logic in
`HiddenContentFilter` so each chokepoint stays a one-line call.

### On device

Debug build, ⌘R, `SPLASH_UNLOCK_PREMIUM=1`.

1. Hide a library, a series and a book → absent from Home, Library, Search, Downloads, Server settings
   and My account → Access.
2. Long-press beside the "All Libraries" chip → Face ID → banner appears and all three return in place
   with lock badges. Cancel the prompt → **nothing** happens.
3. A hidden downloaded book is visible in Downloads while unlocked.
4. *Lock now* → banner and content disappear; you land on Home.
5. Settings → Private lists all three with Unhide; unhiding removes the row immediately.
6. Background while unlocked → the app-switcher shows the blur.
7. Kill and relaunch → locked.
8. Without the purchase and without the env var → the gesture does nothing.
