# App Review notes

Text to paste into **App Store Connect → App Review Information → Notes**, plus the reasoning behind it.

> ⚠️ Fill in the demo server credentials in App Store Connect itself, not here. This file is committed; the
> credentials are not.

---

## Notes to paste

```
Splash is a client for Komga, a self-hosted comic/manga/ebook server. It has no content of its own: the
user points it at a server they run, signs in, and reads their own library.

DEMO SERVER
The app cannot be evaluated without a server, so we are providing one:

  Server URL: <URL>
  Username:   <USER>
  Password:   <PASSWORD>

On first launch, enter the server URL on the sign-in screen, then the username and password.
The demo library contains public-domain comics.

IN-APP PURCHASE
Reading online is free and unlimited. A single non-consumable purchase
(io.heymaia.splash.offline) unlocks two features together:
  1. Downloading books/series for offline reading
  2. Hiding chosen libraries, series and books behind device authentication (Face ID / Touch ID /
     passcode)
Both features present the same purchase; there is only one SKU. Purchases can be restored from the
paywall and from Settings > Purchases > Restore purchases.

APP TRANSPORT SECURITY
The app sets NSAllowsArbitraryLoads. Splash connects only to a Komga server address that the user
types in themselves. Those servers are self-hosted by the user and commonly run over plain HTTP:
either on the local network (a NAS or home server, often with no certificate at all) or on a remote
host the user administers. The app does not connect to any first-party or third-party backend, does
not fetch ads or analytics, and has no hardcoded endpoints. Restricting ATS would make the app unable
to reach the majority of real Komga deployments.

PRIVACY
The app collects no data whatsoever. There is no analytics, no telemetry, no account system of our
own. Everything stays on the device and on the user's own Komga server.

The "private content" feature is deliberately described as hiding, not encryption: it keeps chosen
items out of every list until the user authenticates with Face ID / Touch ID / passcode. Downloaded
files remain ordinary files on disk. We do not describe it as a vault anywhere in the UI.
```

---

## Why ATS stays open

`NSAllowsArbitraryLoads = true` and `NSAllowsLocalNetworking = true` in `swift/Config/Splash-Info.plist`.

This was reviewed and kept deliberately. The three deployment shapes a Komga user actually has are:

| Shape | Example | Needs |
|---|---|---|
| Local network, no TLS | `http://192.168.1.10:25600`, a NAS | `NSAllowsLocalNetworking` |
| Remote host, plain HTTP | `http://komga.example.com` on a VPS the user runs | `NSAllowsArbitraryLoads` |
| Remote host, HTTPS | behind a reverse proxy with a real certificate | nothing special |

`NSAllowsLocalNetworking` alone covers only the first. Dropping `NSAllowsArbitraryLoads` would break the
second, which is a normal way to run Komga — self-hosters frequently reach their server over a VPN or
Tailscale where a public certificate is neither available nor meaningful.

The exemption is defensible because the app has **no hardcoded endpoints at all**: every connection goes to
an address the user typed. There is no first-party backend whose traffic could be downgraded.

## Risk note

This is the second most likely rejection reason after "no demo server" (see `PUBLISHING_PLAN.md`). If a
reviewer pushes back, the answer is the table above — not removing the exemption, which would break real
users.
