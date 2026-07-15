import WidgetKit
import SwiftUI
import AppIntents

// ⚠️ This file is STAGED — it is NOT yet part of any Xcode target.
// A ControlWidget must live in a Widget Extension. To activate it:
//
//   1. Xcode → File → New → Target → Widget Extension
//      (name it e.g. "imjaDNSWidget"; include Control checkbox / Live Activity off).
//   2. Add the App Group "group.dev.peterdsp.imjaDNS" to the new target's
//      Signing & Capabilities.
//   3. Move this file into the widget extension's folder, and add these app
//      files to the extension's target membership (so the intent/provider link):
//        - Features/Intents/DNSIntents.swift        (SetDNSEnabledIntent)
//        - Features/Intents/ProfileProvider.swift
//        - Services/DNSApplyService.swift, DNSManager.swift, PersistenceManager.swift
//        - Features/DNSProfile/DNSProfile.swift, Services/DNSProfileCatalog.swift
//        - Services/DNSLatencyTester.swift
//   4. Register it in the widget bundle's `body` (WidgetBundle).
//
// Requires iOS 18 (ControlWidget). The App Intents in the app target already
// work on iOS 17 for Siri/Shortcuts without this extension.

@available(iOS 18.0, *)
struct imjaDNSControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "dev.peterdsp.imjaDNS.control",
            provider: Provider()
        ) { isActive in
            ControlWidgetToggle(
                "imjaDNS",
                isOn: isActive,
                action: SetDNSEnabledIntent()
            ) { isOn in
                Label(isOn ? "DNS On" : "DNS Off",
                      systemImage: isOn ? "shield.fill" : "shield.slash")
            }
        }
        .displayName("imjaDNS")
        .description("Toggle your custom DNS on or off.")
    }
}

@available(iOS 18.0, *)
extension imjaDNSControl {
    struct Provider: ControlValueProvider {
        var previewValue: Bool { true }

        /// Custom DNS is "on" when a profile is currently active.
        func currentValue() async throws -> Bool {
            await ProfileProvider.activeProfile() != nil
        }
    }
}
