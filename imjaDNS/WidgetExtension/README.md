# imjaDNS Widget Extension (staged)

These files implement the Home/Lock Screen **widget** and the iOS 18 **Control
Center toggle**. They are staged here (outside the app's compiled source) because
a widget lives in its own target, which must be created once in Xcode.

## One-time setup

1. **Xcode → File → New → Target → Widget Extension.** Name it `imjaDNSWidget`.
   Uncheck "Include Live Activity". Xcode creates a folder + a default bundle file.
2. **Delete** Xcode's generated sample widget + its bundle file.
3. **Move these files** into the new target's folder:
   - `imjaDNSWidget.swift` — Home/Lock Screen widget (small, medium w/ quick-switch, accessory).
   - `imjaDNSControl.swift` — Control Center toggle (iOS 18).
   - `imjaDNSWidgetBundle.swift` — the `@main` bundle registering both.
4. **Add the App Group** `group.dev.peterdsp.imjaDNS` to the extension's
   Signing & Capabilities (same as the app).
5. **Add these app files to the extension's Target Membership** (File Inspector →
   Target Membership → check the widget target) so shared code links:
   - `Services/WidgetState.swift`
   - `Services/DNSApplyService.swift`, `DNSManager.swift`, `PersistenceManager.swift`, `DNSLatencyTester.swift`, `DNSProfileCatalog.swift`
   - `Features/DNSProfile/DNSProfile.swift`
   - `Features/Intents/ProfileProvider.swift`, `ProfileEntity.swift`, `DNSIntents.swift`
6. Build & run. Add the widget from the Home Screen gallery; add the toggle from
   Control Center (iOS 18).

## How state flows

The app writes a small `WidgetState` into the App Group on every DNS change and
latency measurement, then calls `WidgetCenter.shared.reloadAllTimelines()`. The
widget's timeline provider reads that state (policy `.never` — event-driven, so
no battery cost). Quick-switch buttons and the toggle run the App Intents that
already ship in the app target.
