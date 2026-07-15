# imjaDNS — "Feature-full" Tracks Design

**Date:** 2026-07-15
**Status:** Proposed
**Scope:** Four new tracks beyond the shipped roadmap — Diagnostics & Trust, Sharing & Sync, App Localization, Apple Watch companion.

---

## Context

Already shipped: DNS management (DoH/DoT/plain via `NEDNSSettingsManager`), speed test + Insights, connection log, custom profiles, network monitor, App Intents/Shortcuts/Control Center, widgets (staged), automation, and cellular-adaptive concurrent probing.

Foundations to reuse:
- **`DNSApplyService`** / `DNSApplying` — single seam for applying/removing DNS.
- **App Group** `group.dev.peterdsp.imjaDNS` + `PersistenceManager` (Codable over the shared suite).
- **`DNSLatencyTester`** — real DNS queries over UDP/DoH/DoT, Swift-6-safe, off-main-actor.
- **App Intents** — `SwitchDNSProfileIntent`, `SetDNSEnabledIntent`, etc.

Constraints (unchanged): **zero-data / on-device**, **cellular first-class**, reuse `DNSManager`.

Confirmed gaps: no iCloud entitlement, no String Catalog, no watchOS target.

---

## Track A — Diagnostics & Trust · **M** · *build first*

Prove the app is actually doing its job. Three on-device checks, surfaced as a "Run Diagnostics" screen (reached from Home or Settings).

### 1. DNS leak test
Confirms the *configured* resolver is the one answering. Query a resolver-echo endpoint that reports which resolver reached it (e.g. Cloudflare's trace, or a TXT lookup of a whoami-style name via the active resolver), compare against the applied profile's servers, and report **Match / Leak**. One network call, no personal data.

### 2. DNSSEC validation check
Query a deliberately DNSSEC-broken domain (e.g. `dnssec-failed.org`). A validating resolver returns SERVFAIL; a non-validating one resolves it. Report **Validates / Does not validate** — reuses `DNSLatencyTester`'s query machinery with response-code inspection.

### 3. Health check
Reachability + latency + encryption status (is the active profile DoH/DoT?) rolled into a single green/amber/red summary, using the existing latency probe and `DNSManager.currentServers`.

**New:** `DiagnosticsFeature` + `DiagnosticsView`; extend `DNSLatencyTester` to expose the DNS response code (RCODE) and the answered address. Pure result-mapping is unit-testable; the network calls are integration-tested manually. **Cellular:** use the adaptive timeout from `SpeedProbe`.

---

## Track B — Sharing & Sync · **M**

### iCloud sync (recommended: `NSUbiquitousKeyValueStore`, not CloudKit)
Custom profiles, favorites, and automation rules are small Codable blobs — well under the 1 MB KVS limit. KVS needs only the **iCloud Key-Value Storage** capability and mirrors automatically across a user's devices; far less work than CloudKit.
- New `CloudSyncManager`: writes the same Codable payloads to KVS on change, observes `didChangeExternallyNotification`, and merges into `PersistenceManager` (last-writer-wins per key; profiles merged by `id`).
- Sync is **opt-in** (Settings toggle) to respect the privacy stance.

### Export / Import
- **Export** a profile (or all) as a `.imjadns` JSON file via `ShareLink` / `UIDocumentPicker`.
- **Import** via the document picker or by opening a `.imjadns` file (register a document type). Validate with existing `DNSValidation` before saving.

### QR share
- Encode a compact profile JSON into a QR (`CIQRCodeGenerator`).
- Scan with `DataScannerViewController` (VisionKit) → parse → validate → save. Great for handing a config to a friend; pairs with the multilingual website.

**Edge cases:** malformed/oversized imports rejected with a clear error; duplicate `id` on import → assign a new `id`. Unit-test encode/decode round-trips and the merge.

---

## Track C — App Localization · **M–L**

Localize the app UI (Greek & Albanian first, scaffold for more), matching the website.

### Approach: String Catalog (`.xcstrings`)
- Add a `Localizable.xcstrings` catalog (Xcode 15+). Xcode auto-extracts `LocalizedStringKey` usages from SwiftUI `Text(...)`.
- Sweep the feature views (Home, Profiles, SpeedTest, Insights, Automation, Settings, Onboarding, Diagnostics) replacing hardcoded `Text("...")` and labels with localizable strings; move user-facing strings out of reducers into the view layer or `LocalizedStringResource`.
- Add `el` and `sq` localizations; provide translations (reuse the website's terminology for consistency).
- Localize App Intent titles/phrases via `LocalizedStringResource`.

**Effort note:** the mechanical string sweep is the bulk of the work (many views). YAGNI: skip localizing developer/debug logs and `os.log` messages. **Testing:** snapshot a couple of screens in each language; verify no layout truncation with longer Albanian/Greek strings.

---

## Track D — Apple Watch companion · **L** · *most setup*

Glanceable status + quick switch on the wrist.

### New watchOS target (`imjaDNS Watch App`)
- **App Groups don't span iOS↔watchOS**, so state moves via **WatchConnectivity** (`WCSession`): the phone pushes the current `WidgetState` (active profile, latency) and the favorites list; the watch shows them.
- **Switching from the watch:** the watch sends a message → the phone runs `DNSApplyService.apply(...)` (DNS changes must happen on the phone; the watch can't apply `NEDNSSettingsManager`). Show a "requires iPhone nearby" state when unreachable.
- **Complication** (WidgetKit on watchOS): active profile + latency on the face, tap to open.

**Reuses:** `WidgetState` shape, `ProfileProvider.favorites()`, the App Intents pattern. **Manual step:** the watchOS target must be created in Xcode (can't be scripted), like the Widget Extension.

---

## Recommended sequencing

1. **Track A — Diagnostics** (buildable now, no new entitlements/targets, reinforces the core value; cellular-testable).
2. **Track B — Sharing & Sync** (KVS + files buildable now; QR scanner needs camera permission string).
3. **Track C — Localization** (self-contained, mechanical; pairs with the website).
4. **Track D — Watch** (last — needs a new target + WatchConnectivity plumbing).

### New capabilities/permissions summary
- **iCloud Key-Value Storage** (Track B sync).
- **Camera** + `NSCameraUsageDescription` (Track B QR scan).
- Document type registration for `.imjadns` (Track B import).
- **watchOS target** + WatchConnectivity (Track D).

### Cross-cutting
- All diagnostics and probes use `SpeedProbe.adaptiveTimeout()` so they behave on cellular.
- Nothing adds background data collection; the leak/DNSSEC tests make explicit, user-initiated network calls only.
