import SwiftUI

enum AppTheme {
    static let brandGradient = LinearGradient(
        colors: [Color(hex: "00D2FF"), Color(hex: "7B61FF"), Color(hex: "6C63FF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [Color(hex: "00D2FF"), Color(hex: "3A7BD5")],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let successGradient = LinearGradient(
        colors: [Color(hex: "11998E"), Color(hex: "38EF7D")],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let warningGradient = LinearGradient(
        colors: [Color(hex: "F2994A"), Color(hex: "F2C94C")],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let dangerGradient = LinearGradient(
        colors: [Color(hex: "FC466B"), Color(hex: "FF5858")],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardCornerRadius: CGFloat = 24
    static let smallCornerRadius: CGFloat = 14
    static let buttonCornerRadius: CGFloat = 16

    static func categoryGradient(for category: DNSCategory) -> LinearGradient {
        let colors = category.gradient.map { Color(hex: String($0.dropFirst())) }
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
