import AppKit
import NotchoraCore
import SwiftUI

extension Color {
    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        })
    }

    static let nAccent = dynamic(
        light: NSColor(srgbRed: 0.16, green: 0.36, blue: 0.92, alpha: 1),
        dark: NSColor(srgbRed: 0.48, green: 0.63, blue: 1.0, alpha: 1)
    )
    static let nAccentSoft = dynamic(
        light: NSColor(srgbRed: 0.16, green: 0.36, blue: 0.92, alpha: 0.10),
        dark: NSColor(srgbRed: 0.48, green: 0.63, blue: 1.0, alpha: 0.16)
    )
    static let nTeal = dynamic(
        light: NSColor(srgbRed: 0.06, green: 0.54, blue: 0.50, alpha: 1),
        dark: NSColor(srgbRed: 0.36, green: 0.82, blue: 0.76, alpha: 1)
    )
    static let nPanel = dynamic(
        light: NSColor(srgbRed: 0.975, green: 0.975, blue: 0.985, alpha: 0.92),
        dark: NSColor(srgbRed: 0.070, green: 0.070, blue: 0.078, alpha: 0.92)
    )
    static let nPanelSolid = dynamic(
        light: NSColor(srgbRed: 0.965, green: 0.965, blue: 0.975, alpha: 1),
        dark: NSColor(srgbRed: 0.072, green: 0.072, blue: 0.079, alpha: 1)
    )
    static let nSurfaceRaised = dynamic(
        light: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.66),
        dark: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.055)
    )
    static let nSurfaceSunken = dynamic(
        light: NSColor(srgbRed: 0.90, green: 0.90, blue: 0.93, alpha: 0.50),
        dark: NSColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.22)
    )
    static let nHairline = dynamic(
        light: NSColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.10),
        dark: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.13)
    )
    static let nHairlineStrong = dynamic(
        light: NSColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.17),
        dark: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.22)
    )
    static let nRail = Color(nsColor: NSColor(srgbRed: 0.025, green: 0.025, blue: 0.030, alpha: 1))
    static let nRailHairline = Color.white.opacity(0.08)
    static let nUserBubble = dynamic(
        light: NSColor(srgbRed: 0.16, green: 0.36, blue: 0.92, alpha: 0.085),
        dark: NSColor(srgbRed: 0.48, green: 0.63, blue: 1.0, alpha: 0.14)
    )
    static let nCodeBackground = dynamic(
        light: NSColor(srgbRed: 0.945, green: 0.945, blue: 0.960, alpha: 1),
        dark: NSColor(srgbRed: 0.035, green: 0.035, blue: 0.042, alpha: 1)
    )
    static let nSuccess = dynamic(
        light: NSColor(srgbRed: 0.10, green: 0.56, blue: 0.36, alpha: 1),
        dark: NSColor(srgbRed: 0.36, green: 0.83, blue: 0.57, alpha: 1)
    )
    static let nWarning = dynamic(
        light: NSColor(srgbRed: 0.72, green: 0.42, blue: 0.02, alpha: 1),
        dark: NSColor(srgbRed: 0.96, green: 0.68, blue: 0.25, alpha: 1)
    )
    static let nDanger = dynamic(
        light: NSColor(srgbRed: 0.80, green: 0.18, blue: 0.20, alpha: 1),
        dark: NSColor(srgbRed: 1.0, green: 0.42, blue: 0.45, alpha: 1)
    )
    static let nTextPrimary = Color.primary
    static let nTextSecondary = Color.secondary
    static let nTextTertiary = Color.primary.opacity(0.42)
    static let nIcon = Color.primary.opacity(0.64)
    static let nIconMuted = Color.primary.opacity(0.42)
    static let nControlBackground = Color(nsColor: .controlBackgroundColor)

    static func providerTint(_ provider: AIProviderID) -> Color {
        switch provider {
        case .openAI:
            dynamic(
                light: NSColor(srgbRed: 0.02, green: 0.48, blue: 0.36, alpha: 1),
                dark: NSColor(srgbRed: 0.26, green: 0.82, blue: 0.64, alpha: 1)
            )
        case .anthropic:
            dynamic(
                light: NSColor(srgbRed: 0.66, green: 0.31, blue: 0.17, alpha: 1),
                dark: NSColor(srgbRed: 0.95, green: 0.56, blue: 0.38, alpha: 1)
            )
        case .gemini:
            dynamic(
                light: NSColor(srgbRed: 0.16, green: 0.38, blue: 0.82, alpha: 1),
                dark: NSColor(srgbRed: 0.47, green: 0.66, blue: 1.0, alpha: 1)
            )
        }
    }
}

extension Font {
    static let nDisplay = Font.system(size: 25, weight: .semibold, design: .default)
    static let nTitle = Font.system(size: 18, weight: .semibold, design: .default)
    static let nHeadline = Font.system(size: 13.5, weight: .semibold, design: .default)
    static let nBody = Font.system(size: 13.5, weight: .regular, design: .default)
    static let nBodyMedium = Font.system(size: 13.5, weight: .medium, design: .default)
    static let nSmall = Font.system(size: 12, weight: .regular, design: .default)
    static let nSmallMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let nCaption = Font.system(size: 10.5, weight: .medium, design: .default)
    static let nCaptionRegular = Font.system(size: 10.5, weight: .regular, design: .default)
    static let nCode = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let nCodeSmall = Font.system(size: 10.5, weight: .regular, design: .monospaced)
    static let nBrand = Font.system(size: 10.5, weight: .bold, design: .default)
}

enum Metric {
    static let panelRadius: CGFloat = 26
    static let surfaceRadius: CGFloat = 18
    static let controlRadius: CGFloat = 10
    static let compactRadius: CGFloat = 13
    static let sidebarWidth: CGFloat = 238
    static let contentMaxWidth: CGFloat = 760
    static let horizontalPadding: CGFloat = 18
}

extension Animation {
    static let notchSpring = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let notchCollapse = Animation.spring(response: 0.30, dampingFraction: 0.92)
    static let quick = Animation.easeOut(duration: 0.16)
    static let soft = Animation.easeInOut(duration: 0.24)
}

extension View {
    @ViewBuilder
    func reduceMotionAwareAnimation<V: Equatable>(_ value: V, animation: Animation = .notchSpring) -> some View {
        modifier(ReduceMotionAnimation(value: value, animation: animation))
    }
}

private struct ReduceMotionAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: V
    let animation: Animation

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}
