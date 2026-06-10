import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    private let totalPages = 4

    var body: some View {
        ZStack {
            AnimatedMeshBackground()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    onboardingPage(
                        icon: "shield.checkered",
                        iconGradient: AppTheme.brandGradient,
                        title: "Welcome to imjaDNS",
                        subtitle: "Take control of your DNS.\nFaster browsing. Better privacy.\nNo VPN required."
                    )
                    .tag(0)

                    onboardingPage(
                        icon: "bolt.shield.fill",
                        iconGradient: AppTheme.accentGradient,
                        title: "15+ DNS Providers",
                        subtitle: "Choose from Cloudflare, Google, AdGuard, Quad9, and more.\nOrganized by what matters: Privacy, Speed, Family Safety."
                    )
                    .tag(1)

                    onboardingPage(
                        icon: "lock.shield.fill",
                        iconGradient: AppTheme.successGradient,
                        title: "Encrypted DNS",
                        subtitle: "DNS over HTTPS and DNS over TLS.\nYour queries are encrypted end-to-end.\nNo one can see what you browse."
                    )
                    .tag(2)

                    onboardingPage(
                        icon: "gauge.with.dots.needle.33percent",
                        iconGradient: AppTheme.warningGradient,
                        title: "Speed Test & Monitor",
                        subtitle: "Test every provider's latency.\nFind the fastest DNS for your location.\nMonitor your connection in real-time."
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                pageIndicator

                actionButton
                    .padding(.horizontal, 40)
                    .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Page Content

    private func onboardingPage(icon: String, iconGradient: LinearGradient, title: String, subtitle: String) -> some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 130, height: 130)
                    .overlay {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }

                Image(systemName: icon)
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(iconGradient)
            }

            VStack(spacing: 14) {
                Text(title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage
                          ? AnyShapeStyle(AppTheme.accentGradient)
                          : AnyShapeStyle(Color.secondary.opacity(0.3)))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button {
            if currentPage < totalPages - 1 {
                withAnimation { currentPage += 1 }
            } else {
                onComplete()
            }
        } label: {
            Text(currentPage < totalPages - 1 ? "Continue" : "Get Started")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(AppTheme.accentGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                .shadow(color: Color(hex: "00D2FF").opacity(0.3), radius: 16, x: 0, y: 8)
        }
    }
}
