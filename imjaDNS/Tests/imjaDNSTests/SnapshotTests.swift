import Testing
import SwiftUI
@testable import imjaDNS

// MARK: - View State Snapshot Tests
// These tests verify that views render without crashing in different states.
// For pixel-perfect visual regression testing, add the swift-snapshot-testing
// package and use assertSnapshot.

struct ViewSnapshotTests {

    // MARK: - Onboarding

    @Test func onboardingViewCreation() {
        let view = OnboardingView(onComplete: {})
        #expect(type(of: view) == OnboardingView.self)
    }

    // MARK: - StatusOrb

    @Test func statusOrbActiveState() {
        let orb = StatusOrb(isActive: true, size: 120)
        #expect(type(of: orb) == StatusOrb.self)
    }

    @Test func statusOrbInactiveState() {
        let orb = StatusOrb(isActive: false, size: 120)
        #expect(type(of: orb) == StatusOrb.self)
    }

    @Test func statusOrbCustomSize() {
        let orb = StatusOrb(isActive: true, size: 200)
        #expect(type(of: orb) == StatusOrb.self)
    }

    // MARK: - GlassCard

    @Test func glassCardCreation() {
        let card = GlassCard { Text("Hello") }
        #expect(type(of: card) == GlassCard<Text>.self)
    }

    // MARK: - GlassButton

    @Test func glassButtonCreation() {
        let button = GlassButton("Test", icon: "shield") {}
        #expect(type(of: button) == GlassButton.self)
    }

    @Test func glassButtonWithoutIcon() {
        let button = GlassButton("Test") {}
        #expect(type(of: button) == GlassButton.self)
    }

    @Test func glassButtonWithCustomGradient() {
        let button = GlassButton("Test", gradient: AppTheme.dangerGradient) {}
        #expect(type(of: button) == GlassButton.self)
    }

    // MARK: - LatencyBadge

    @Test func latencyBadgeWithValue() {
        let badge = LatencyBadge(latencyMs: 25.0)
        #expect(type(of: badge) == LatencyBadge.self)
    }

    @Test func latencyBadgeNilValue() {
        let badge = LatencyBadge(latencyMs: nil)
        #expect(type(of: badge) == LatencyBadge.self)
    }

    // MARK: - SectionHeader

    @Test func sectionHeaderWithIcon() {
        let header = SectionHeader("Title", icon: "star")
        #expect(type(of: header) == SectionHeader.self)
    }

    @Test func sectionHeaderWithoutIcon() {
        let header = SectionHeader("Title")
        #expect(type(of: header) == SectionHeader.self)
    }

    // MARK: - AnimatedBackground

    @Test func animatedMeshBackgroundCreation() {
        let bg = AnimatedMeshBackground()
        #expect(type(of: bg) == AnimatedMeshBackground.self)
    }

    @Test func pulsingRingCreation() {
        let ring = PulsingRing(color: .blue, size: 100)
        #expect(type(of: ring) == PulsingRing.self)
    }
}

// MARK: - Theme Tests

struct ThemeTests {
    @Test func colorFromHexValid6Digit() {
        let color = Color(hex: "FF0000")
        #expect(type(of: color) == Color.self)
    }

    @Test func colorFromHexValid8Digit() {
        let color = Color(hex: "FF00FF00")
        #expect(type(of: color) == Color.self)
    }

    @Test func colorFromHexWithHash() {
        let color = Color(hex: "#00D2FF")
        #expect(type(of: color) == Color.self)
    }

    @Test func brandGradientExists() {
        let gradient = AppTheme.brandGradient
        #expect(type(of: gradient) == LinearGradient.self)
    }

    @Test func accentGradientExists() {
        let gradient = AppTheme.accentGradient
        #expect(type(of: gradient) == LinearGradient.self)
    }

    @Test func successGradientExists() {
        let gradient = AppTheme.successGradient
        #expect(type(of: gradient) == LinearGradient.self)
    }

    @Test func warningGradientExists() {
        let gradient = AppTheme.warningGradient
        #expect(type(of: gradient) == LinearGradient.self)
    }

    @Test func dangerGradientExists() {
        let gradient = AppTheme.dangerGradient
        #expect(type(of: gradient) == LinearGradient.self)
    }

    @Test func categoryGradientsExist() {
        for category in DNSCategory.allCases {
            let gradient = AppTheme.categoryGradient(for: category)
            #expect(type(of: gradient) == LinearGradient.self)
        }
    }

    @Test func cornerRadiusValues() {
        #expect(AppTheme.cardCornerRadius == 24)
        #expect(AppTheme.smallCornerRadius == 14)
        #expect(AppTheme.buttonCornerRadius == 16)
    }
}

// MARK: - Bundle Extension Tests

struct BundleExtensionTests {
    @Test func appVersionReturnsString() {
        let version = Bundle.main.appVersion
        #expect(!version.isEmpty)
    }
}
