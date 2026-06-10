import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
            }
    }
}

struct GlassButton: View {
    let title: String
    let icon: String?
    let gradient: LinearGradient
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        gradient: LinearGradient = AppTheme.accentGradient,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.gradient = gradient
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(gradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
            .shadow(color: Color(hex: "00D2FF").opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: UUID())
    }
}

struct GlassToggle: View {
    let title: String
    let subtitle: String?
    let icon: String
    @Binding var isOn: Bool

    init(_ title: String, subtitle: String? = nil, icon: String, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self._isOn = isOn
    }

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(AppTheme.accentGradient)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(Color(hex: "00D2FF"))
            }
        }
    }
}

struct StatusOrb: View {
    let isActive: Bool
    let size: CGFloat

    init(isActive: Bool, size: CGFloat = 120) {
        self.isActive = isActive
        self.size = size
    }

    @State private var animateGlow = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: isActive
                            ? [Color(hex: "00D2FF").opacity(0.3), .clear]
                            : [Color.gray.opacity(0.15), .clear],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.8
                    )
                )
                .frame(width: size * 1.6, height: size * 1.6)
                .scaleEffect(animateGlow ? 1.1 : 0.95)

            Circle()
                .fill(
                    RadialGradient(
                        colors: isActive
                            ? [Color(hex: "00D2FF").opacity(0.5), Color(hex: "7B61FF").opacity(0.3)]
                            : [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size * 0.85, height: size * 0.85)
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: isActive
                                    ? [Color(hex: "00D2FF").opacity(0.6), Color(hex: "7B61FF").opacity(0.2)]
                                    : [.white.opacity(0.2), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }

            Image(systemName: isActive ? "shield.checkered" : "shield.slash")
                .font(.system(size: size * 0.28, weight: .medium))
                .foregroundStyle(
                    isActive ? AppTheme.accentGradient : LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateGlow = true
            }
        }
    }
}

struct LatencyBadge: View {
    let latencyMs: Double?

    var body: some View {
        if let latency = latencyMs {
            HStack(spacing: 4) {
                Circle()
                    .fill(latencyColor)
                    .frame(width: 6, height: 6)
                Text("\(Int(latency))ms")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.ultraThinMaterial))
        }
    }

    private var latencyColor: Color {
        guard let latency = latencyMs else { return .gray }
        if latency < 30 { return Color(hex: "38EF7D") }
        if latency < 100 { return Color(hex: "F2C94C") }
        return Color(hex: "FC466B")
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String?

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accentGradient)
            }
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
        }
    }
}
