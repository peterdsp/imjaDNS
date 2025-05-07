# imjaDNS

**imjaDNS** is a SwiftUI-based iOS application that allows users to view, manage, and apply custom DNS profiles system-wide using Apple's `NEDNSSettingsManager`. It loads default profiles from Firebase Remote Config and supports user-defined DNS servers with persistent storage.

---

## ✨ Features

- ✅ View currently active system DNS
- 🌐 Detect current network (Wi-Fi, Cellular, Ethernet)
- 📥 Fetch curated DNS profiles from Firebase Remote Config
- ➕ Add your own custom DNS profiles (persisted locally)
- 🔁 Auto-apply last used DNS at app launch
- ⚙️ First-time setup alert with shortcut to DNS settings
- 🧩 Built with SwiftUI + Composable Architecture (TCA)

---

## 📦 Requirements

- iOS 16.0+
- Xcode 15+
- Firebase Project with Remote Config enabled
- Entitlements:
  - `com.apple.developer.networking.networkextension` → `dns-settings`

---

## 🔧 Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/peterdsp/imjaDNS.git

	2.	Install dependencies:
	    •	Add Firebase SDK (via Swift Package Manager)
	    •	Enable Firestore and Remote Config in your Firebase Console
	3.	Configure your GoogleService-Info.plist and add it to the project.
	4.	Add a Remote Config parameter:

      Key: dns_profiles
      Value: {
        "profiles": [
          {
            "name": "Google",
            "servers": ["8.8.8.8", "8.8.4.4"]
          },
          ...
        ]
      }


	5.	Enable the DNS Settings Entitlement in your Apple Developer portal.

⸻

🧠 Architecture
	•	Composable Architecture (TCA): State management and effects.
	•	SwiftUI: UI framework for views.
	•	Firebase Remote Config: Remote profile loading.
	•	UserDefaults: Stores last used DNS and custom profiles.
	•	NEDNSSettingsManager: Applies system-wide DNS settings (no VPN used).

⸻

🛠 Developer Notes
	•	DNS changes require user interaction: Users must go to Settings > VPN & Device Management > DNS and select imjaDNS.
	•	Custom profiles are stored using UserDefaults and restored on every launch.
	•	Remote Config profiles load only once per session to minimize bandwidth and server hits.

⸻

📸 Screenshots

![4](https://github.com/user-attachments/assets/a37b1e34-b4cb-4a6e-9183-d9573bf2fd0d)

⸻

📄 License

MIT License © Petros Dhespollari 2025
