# imjaDNS — Next Features Design

**Date:** 2026-07-15
**Status:** Proposed
**Scope:** Four feature tracks — App Intents/Shortcuts, Widgets, Per-Wi-Fi automation, Latency analytics — plus one shared prerequisite.

---

## Context

Current app (SwiftUI + The Composable Architecture):

- **Features:** Home, DNSProfile, SpeedTest, ConnectionLog, Settings, Onboarding — each with its own `Store`, composed in a `TabView` in `imjaDNSApp` (no root reducer).
- **Services (singletons):** `DNSManager` (`@MainActor`, wraps `NEDNSSettingsManager`), `PersistenceManager` (`actor` over `UserDefaults`), `NetworkMonitor` (`NWPathMonitor`), `DNSProfileCatalog` (built-ins), `FirebaseManager` (remote profiles).
- **Targets:** main app, VPN Extension.
- **App Group `group.dev.peterdsp.imjaDNS`** is already declared in `imjaDNS.entitlements`.

Guiding constraints:

- **Zero-data privacy promise** — everything stays on-device. No new analytics or network calls beyond DNS/DoH probes.
- **Reuse `DNSManager`** — it already performs every real DNS operation. New surfaces are thin entry points, not reimplementations.

---

## Foundation 0 — App Group persistence (shared prerequisite) · **S**

Widgets and App Intent extensions run in **separate processes** and cannot read `UserDefaults.standard`. They can read a shared App Group suite. The group already exists; `PersistenceManager` just isn't using it.

**Change:** in `PersistenceManager`, replace

```swift
private let defaults = UserDefaults.standard
```

with

```swift
private let defaults = UserDefaults(suiteName: "group.dev.peterdsp.imjaDNS") ?? .standard
```

**Migration:** on first launch after update, if the group suite has no `activeProfileID`, copy all known keys from `.standard` into the group suite once (guard with a `didMigrateToAppGroup` bool). Keeps existing users' profiles/favorites/log intact.

**Also add the App Group** to the VPN Extension and every new target's entitlements.

**Testing:** unit-test the migration copies each key exactly once and is idempotent.

---

## Feature 1 — App Intents + Shortcuts + Control Center · **S–M** · *build first*

The keystone: one intent layer that Siri, Shortcuts, the widget, and the Control Center toggle all reuse.

### New target
`imjaDNSIntents` (App Intents extension) — or intents compiled into the app target (simpler; start here). Add App Group entitlement.

### Intents
| Intent | Parameters | Action |
|---|---|---|
| `SwitchDNSProfileIntent` | `profile: ProfileEntity` | `try await DNSManager.shared.applyProfile(...)`, persist `activeProfileID`, log entry |
| `DisableCustomDNSIntent` | — | `try await DNSManager.shared.disableCustomDNS()` |
| `RunSpeedTestIntent` | — | run `DNSLatencyTester`, return best provider as dialog + value |
| `CurrentDNSIntent` | — | returns active profile name (for "what's my DNS?") |

`ProfileEntity: AppEntity` with an `EntityQuery` backed by `DNSProfileCatalog.builtIn` + `PersistenceManager.loadCustomProfiles()`, so Shortcuts shows a live profile picker.

`imjaDNSShortcuts: AppShortcutsProvider` ships phrases like `"Switch to \(.applicationName) profile \(\.$profile)"` and `"Turn off \(.applicationName) DNS"`.

### Control Center (iOS 18) · **S**
`ControlWidget` with a `ControlWidgetToggle` bound to a `SetDNSEnabledIntent` (App Intent conforming to `SetValueIntent`). Reuses `DisableCustomDNSIntent` logic and the last-active profile.

### Design notes / edge cases
- Intents run **out-of-process** → talk to `DNSManager`/`PersistenceManager` singletons directly; never assume a live TCA store.
- Applying DNS can require the user to approve the config in Settings the first time — surface a `.needsToContinueInForeground` result when not yet approved.
- All intents `async throws`; map `DNSError` to `IntentError` with readable messages.

### Testing
Unit-test each intent's `perform()` against a mocked `DNSManager` (extract a `DNSApplying` protocol so the singleton can be stubbed).

---

## Feature 2 — Home/Lock Screen Widget · **M**

Shows the active profile and its last measured latency; tap to open; quick-switch from favorites.

### New target
`imjaDNSWidget` (WidgetKit extension) + App Group entitlement.

### Data flow
- App writes a small `WidgetState` (active profile name, category icon/gradient, last latency, timestamp) to the App Group suite whenever DNS changes; calls `WidgetCenter.shared.reloadAllTimelines()`.
- Widget's `TimelineProvider` reads `WidgetState` from the group. Timeline is `.never` (event-driven) — refreshed by the app, not on a schedule, so no battery cost.

### Widget families
- `.systemSmall` / `.accessoryRectangular` (Lock Screen): active profile + latency chip.
- `.systemMedium`: active profile + **interactive** favorite buttons, each wired to `SwitchDNSProfileIntent` (iOS 17 interactive widgets) — instant switch without opening the app.
- `.accessoryInline`: "DNS: Cloudflare".

### Edge cases
- No custom DNS active → "System Default" state.
- Latency stale (> 24h) → hide the number rather than show a misleading old value.
- Respect Liquid Glass styling via `containerBackground`.

### Testing
Snapshot-test each family for active / disabled / stale states.

---

## Feature 3 — Per-Wi-Fi automation · **M–L** · *the differentiator*

Auto-apply a profile based on the current network. Built on `NetworkMonitor`.

### Prerequisites
- `NetworkMonitor` currently exposes `connectionType` but **not SSID**. Add SSID capture via `NEHotspotNetwork.fetchCurrent(...)` (needs **Access Wi-Fi Information** entitlement) — falls back to "any Wi-Fi / any Cellular" rules when SSID is unavailable (e.g. permission denied).
- Reading SSID also requires **Location When In Use** authorization on modern iOS; gate the SSID-specific UI behind that permission with a clear explainer.

### New feature module
`AutomationFeature` (TCA) + `AutomationRule` model:

```swift
struct AutomationRule: Identifiable, Codable, Equatable {
    let id: UUID
    var trigger: Trigger          // .ssid(String) | .anyWifi | .cellular | .schedule(from,to)
    var profileID: UUID?          // nil = disable custom DNS
    var isEnabled: Bool
}
```

Persist rules via `PersistenceManager` (new key `automationRules`).

### Engine
`AutomationEngine` (actor): subscribes to `NetworkMonitor` changes (and a scheduled timer for time rules), finds the first matching enabled rule, and calls `DNSManager.applyProfile` / `disableCustomDNS` if the target differs from the active profile. Debounce network flaps (e.g. 3s settle). Runs while the app is foreground/active; document that iOS limits fully-background auto-switching (best-effort on next launch/BGTask).

### Scheduled profiles (subset, ships independently)
`.schedule(from:to:)` triggers via `BGAppRefreshTask` + local notification ("Family-Safe DNS now active"). Simpler than SSID; no extra permissions — ship it first if Wi-Fi permissions add friction.

### Edge cases
- Two rules match → deterministic priority (list order, top wins).
- User manually overrides after an auto-apply → suppress re-applying that same network for the session.
- Permission denied → degrade to `.anyWifi` / `.cellular` / schedule rules only.

### Testing
Unit-test rule matching (SSID/type/schedule) and the "target differs" guard against a mocked monitor + clock.

---

## Feature 4 — Latency analytics · **M**

Turn persisted speed-test history into insight. On-device only.

### Data
`SpeedTestResult` (already persisted, with `profileName`, `server`, `latencyMs`, `timestamp`). Consider raising the retention cap and adding a `protocolType` tag.

### New view (extends SpeedTest or a new `InsightsFeature`)
- **Latency-over-time** line chart per provider (Swift Charts), selectable providers, time window (24h / 7d / 30d).
- **Leaderboard**: median latency per provider over the window, best highlighted.
- **"Fastest right now"** — a `RunSpeedTestIntent`-backed refresh that ranks providers and offers one-tap apply of the winner.
- **Reliability** — % of probes that returned a valid response per provider (surfaces flaky resolvers).

### Design notes
- Aggregate on a background actor; charts read summarized structs, not raw arrays.
- Empty state (no history yet) → CTA to run the first speed test.
- Keep the animated ring from the existing SpeedTest as the "live" tab; analytics is the "history" tab.

### Testing
Unit-test the aggregation (median, reliability %, windowing) with fixed sample data.

---

## Recommended sequencing

1. **Foundation 0** (App Group persistence) — unblocks 1 & 2.
2. **Feature 1** (App Intents) — keystone; Shortcuts + Control Center land here.
3. **Feature 2** (Widget) — reuses the intents for quick-switch.
4. **Feature 4** (Latency analytics) — self-contained, no new permissions, high polish-per-effort.
5. **Feature 3** (Per-Wi-Fi automation) — highest value but most permission/entitlement surface; ship **scheduled profiles** subset first, SSID rules second.

### New entitlements/capabilities summary
- App Group on all new targets (exists).
- Access Wi-Fi Information + Location When In Use (Feature 3, SSID only).
- Background Modes: Background fetch/processing (Feature 3 schedules).
- Siri (Feature 1, if using the Siri phrase surface).

### Cross-cutting
- Extract a `DNSApplying` protocol from `DNSManager` so intents, the engine, and tests share one seam.
- Every new surface writes `WidgetCenter.reloadAllTimelines()` after a DNS change so the widget/Control Center stay truthful.
- Nothing here adds a network call beyond DNS probes — the zero-data promise holds.
