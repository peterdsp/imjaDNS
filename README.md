# imjaDNS

**imjaDNS** is a premium iOS DNS management app that gives you full control over your device's DNS settings — no VPN required. Built with SwiftUI and The Composable Architecture, it features a stunning Liquid Glass design, 15+ built-in DNS providers, speed testing, and support for DNS over HTTPS (DoH) and DNS over TLS (DoT).

![imjaDNS](https://github.com/user-attachments/assets/70d0a3c0-2f5d-4232-9735-47e852246f6c)

---

## Features

### DNS Management
- **15 built-in DNS providers** across 5 categories: Privacy, Speed, Family Safe, Security, and Gaming
- **DNS over HTTPS (DoH)** and **DNS over TLS (DoT)** protocol support
- **Custom DNS profiles** — add your own servers with full IPv4, IPv6, DoH URL, and DoT hostname validation
- **One-tap apply** — activate any DNS profile system-wide via `NEDNSSettingsManager`
- **Favorites** — bookmark your go-to profiles for quick access

### Speed Test
- **Latency benchmarking** for all DNS providers with animated ring UI
- **Ranked results** with color-coded latency bars
- **Historical results** — track performance over time

### Connection Log
- **Timestamped history** of all DNS apply/remove/error events
- **Color-coded action badges** for quick scanning
- **Persistent storage** — log survives app restarts

### Network Monitoring
- **Real-time network type detection** (Wi-Fi, Cellular, Ethernet) via `NWPathMonitor`
- **Live status dashboard** with animated shield orb indicator

### Design
- **Liquid Glass UI** — glass morphism cards with `ultraThinMaterial` and gradient borders
- **Animated mesh background** with floating gradient blobs
- **Category-specific color gradients** for visual organization
- **Dark-mode optimized** throughout

### Onboarding
- **4-page guided onboarding** for first-time users
- **DNS setup walkthrough** with link to system Settings

---

## Built-In DNS Providers

| Category | Providers |
|----------|-----------|
| **Privacy** | Cloudflare (1.1.1.1), Quad9, Mullvad DNS |
| **Speed** | Google DNS, NextDNS, Cloudflare WARP |
| **Family Safe** | Cloudflare Family, CleanBrowsing, OpenDNS Family Shield |
| **Security** | AdGuard DNS, Control D, Quad9 + ECS |
| **Gaming** | Google Low-Latency, Level3, OpenDNS |

---

## Architecture

- **[The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture)** — `@Reducer` macro with `@ObservableState` for type-safe state management and testable effects
- **SwiftUI** — declarative UI with custom design system components
- **NEDNSSettingsManager** — applies system-wide DNS settings without a VPN tunnel
- **Firebase Remote Config** — remote profile loading for server-side DNS catalog updates
- **Actor-based persistence** — thread-safe `PersistenceManager` actor using `UserDefaults`
- **NWPathMonitor** — real-time network interface monitoring

---

## Testing

imjaDNS includes 100+ automated tests:

- **Unit tests** — DNS validation (IPv4, IPv6, DoH, DoT), model encoding/decoding, catalog integrity
- **Reducer tests** — all 5 TCA features tested with `TestStore` and `exhaustivity = .off`
- **Snapshot tests** — view creation verification, theme constants, component instantiation
- **UI tests** — launch performance and launch state verification

---

## Requirements

- iOS 17.0+
- Xcode 16+
- Swift 5.9+

---

## Getting Started

1. Clone the repository
2. Open `imjaDNS/imjaDNS.xcodeproj` in Xcode
3. Resolve Swift packages (TCA, Firebase)
4. Build and run on a device or simulator
5. After applying a DNS profile, go to **Settings > VPN & Device Management > DNS** and select **imjaDNS**

---

## Privacy

imjaDNS changes your DNS resolver — it does **not** create a VPN tunnel, does **not** proxy your traffic, and does **not** collect any browsing data. See the full [Privacy Policy](PrivacyPolicy.md).

---

## License

[License &copy; Petros Dhespollari 2025](LICENSE.md)
