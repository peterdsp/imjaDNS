import WidgetKit
import SwiftUI

// ⚠️ STAGED — this is the @main entry point for the Widget Extension target.
// When you create the extension (see imjaDNSControl.swift header), Xcode makes
// its own bundle file; replace it with this one so both the Home/Lock Screen
// widget and the iOS 18 Control Center toggle are registered.

@main
struct imjaDNSWidgetBundle: WidgetBundle {
    var body: some Widget {
        imjaDNSWidget()
        if #available(iOS 18.0, *) {
            imjaDNSControl()
        }
    }
}
