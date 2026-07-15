# imjaDNS Watch App (staged)

A glanceable Apple Watch companion: shows the active DNS profile + latency,
switches favorites, and turns DNS off — all by talking to the iPhone over
WatchConnectivity (only the phone can change `NEDNSSettingsManager`).

These files are staged outside the compiled tree because a watchOS app needs
its own target, which must be created in Xcode.

## One-time setup

1. **Xcode → File → New → Target → watchOS → App.** Name it `imjaDNS Watch App`.
   Choose "Watch App for iOS App" so it pairs with the phone app.
2. **Delete** the sample `ContentView`/`App` Xcode generates.
3. **Move these files** into the watch target's folder:
   - `imjaDNSWatchApp.swift` — `@main` entry
   - `WatchContentView.swift` — the UI
   - `WatchConnectivityManager.swift` — WCSession client
4. Build & run on a paired watch/simulator.

## How it works

- The phone's `PhoneConnectivityManager` (already in the iOS app target) publishes
  the current `WidgetState` + favorites via `updateApplicationContext` whenever DNS
  changes, and applies profile changes the watch requests.
- The watch renders that context and sends `{"action":"apply","profileID":…}` or
  `{"action":"disable"}` back. When the phone is unreachable the last-known state
  is shown; changes take effect once the phone is in range.

## Optional: complication

Add a WidgetKit complication in the watch target reusing the same context shape
(active profile + latency) for an at-a-glance face display.
