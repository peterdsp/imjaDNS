# imjaDNS

**imjaDNS** is a SwiftUI-based iOS application that allows users to view, manage, and apply custom DNS profiles system-wide using Apple's `NEDNSSettingsManager`. It loads default profiles from Firebase Remote Config and supports user-defined DNS servers with persistent storage.

![imjaDNS](https://github.com/user-attachments/assets/70d0a3c0-2f5d-4232-9735-47e852246f6c)

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

🧠 Architecture
	
•	Composable Architecture (TCA): State management and effects.
	
•	SwiftUI: UI framework for views.
	
•	Firebase Remote Config: Remote profile loading.
	
•	UserDefaults: Stores last used DNS and custom profiles.
	
•	NEDNSSettingsManager: Applies system-wide DNS settings (no VPN used).

---

🛠 Developer Notes
	
•	DNS changes require user interaction: Users must go to Settings > VPN & Device Management > DNS and select imjaDNS.
	
•	Custom profiles are stored using UserDefaults and restored on every launch.
	
•	Remote Config profiles load only once per session to minimize bandwidth and server hits.

---

📄 License

MIT License © Petros Dhespollari 2025
