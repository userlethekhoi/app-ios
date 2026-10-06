import SwiftUI

/// Shared visual language for the NappStore UI: near-black canvas, dark system
/// gray cards, iOS system accent colors and hairline borders.
extension Color {
    static let iappayBackground = Color.black
    static let iappaySurface = Color(hex: 0x0C0C0E)
    static let iappayCard = Color(hex: 0x151517)
    static let iappayCardRaised = Color(hex: 0x1C1C1E)
    static let iappayBorder = Color(hex: 0x2E2E32)

    static let iappayAccent = Color(hex: 0x0A84FF)      // systemBlue (dark)
    static let iappayGreen = Color(hex: 0x30D158)       // systemGreen (dark)
    static let iappayYellow = Color(hex: 0xFFD60A)      // systemYellow (dark)
    static let iappayOrange = Color(hex: 0xFF9F0A)      // systemOrange (dark)
    static let iappayRed = Color(hex: 0xFF453A)         // systemRed (dark)
    static let iappayCyan = Color(hex: 0x64D2FF)        // systemCyan (dark)

    static let iappayBadgeHidden = Color(hex: 0x2C2C2E)
    static let iappayBadgeTrialBg = Color(hex: 0x0C2B1D)

    static let iappayTextPrimary = Color.white
    static let iappayTextSecondary = Color(hex: 0x98989F)
    static let iappayTextMuted = Color(hex: 0x636366)

    // Compatibility aliases used by the secondary inspector screens.
    static let darkBackground = iappayBackground
    static let darkSurface = iappaySurface
    static let darkCard = iappayCard
    static let darkBorder = iappayBorder
    static let accentBlue = iappayAccent
    static let purpleTrial = iappayGreen
    static let successGreen = iappayGreen
    static let errorRed = iappayRed
    static let warningYellow = iappayYellow
    static let textPrimary = iappayTextPrimary
    static let textSecondary = iappayTextSecondary
    static let textMuted = iappayTextMuted

    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension View {
    func referenceCard(cornerRadius: CGFloat = 13, stroke: Color = .iappayBorder) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.iappayCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke.opacity(0.7), lineWidth: 0.5)
            )
    }

    func sectionLabelStyle() -> some View {
        self
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.iappayTextSecondary)
            .textCase(.uppercase)
            .tracking(0.4)
    }
}
