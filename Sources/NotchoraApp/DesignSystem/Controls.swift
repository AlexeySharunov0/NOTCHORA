import NotchoraCore
import SwiftUI

enum NButtonVariant {
    case primary
    case secondary
    case ghost
    case danger
}

struct NButtonStyle: ButtonStyle {
    var variant: NButtonVariant = .secondary
    var compact = false
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        NButtonStyleBody(configuration: configuration, variant: variant, compact: compact, fullWidth: fullWidth)
    }

    struct NButtonStyleBody: View {
        let configuration: Configuration
        let variant: NButtonVariant
        let compact: Bool
        let fullWidth: Bool
        @State private var hovered = false

        var body: some View {
            configuration.label
                .font(.nSmallMedium)
                .foregroundStyle(foreground)
                .padding(.horizontal, compact ? 10 : 13)
                .frame(height: compact ? 26 : 32)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous)
                        .strokeBorder(border, lineWidth: 0.8)
                }
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .scaleEffect(configuration.isPressed ? 0.975 : 1)
                .opacity(configuration.isPressed ? 0.86 : 1)
                .onHover { hovered = $0 }
                .animation(.quick, value: hovered)
                .animation(.quick, value: configuration.isPressed)
        }

        private var foreground: Color {
            switch variant {
            case .primary: .white
            case .secondary: .nTextPrimary
            case .ghost: .nTextSecondary
            case .danger: .nDanger
            }
        }

        private var background: Color {
            switch variant {
            case .primary:
                Color.nAccent.opacity(hovered ? 1 : 0.92)
            case .secondary:
                Color.nSurfaceRaised.opacity(hovered ? 1 : 0.72)
            case .ghost:
                Color.primary.opacity(hovered ? 0.06 : 0)
            case .danger:
                Color.nDanger.opacity(hovered ? 0.13 : 0.08)
            }
        }

        private var border: Color {
            switch variant {
            case .primary: .white.opacity(0.12)
            case .secondary: .nHairline
            case .ghost: .clear
            case .danger: .nDanger.opacity(0.22)
            }
        }
    }
}

struct NIconButton: View {
    let symbol: String
    var label: String? = nil
    var size: CGFloat = 28
    var tint: Color? = nil
    var isActive = false
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    private var neutral: Color {
        colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.62)
    }

    private var hoverColor: Color {
        colorScheme == .dark ? Color.white : Color.black.opacity(0.84)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(isActive ? Color.nAccent : (hovered ? hoverColor : (tint ?? neutral)))
                .frame(width: size, height: size)
                .background {
                    RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                        .fill(isActive ? Color.nAccentSoft : (hovered ? hoverColor.opacity(0.07) : .clear))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(label ?? "")
        .accessibilityLabel(label ?? symbol)
        .onHover { hovered = $0 }
        .animation(.quick, value: hovered)
    }
}

struct ProviderGlyph: View {
    let provider: AIProviderID
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(Color.providerTint(provider).opacity(0.14))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                        .strokeBorder(Color.providerTint(provider).opacity(0.26), lineWidth: 0.7)
                }
            Text(provider.monogram)
                .font(.system(size: size * 0.52, weight: .bold, design: .rounded))
                .foregroundStyle(Color.providerTint(provider))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct StatusDot: View {
    var color: Color = .nSuccess
    var pulsing = false
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .overlay {
                if pulsing {
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: 1)
                        .scaleEffect(animate ? 2.1 : 1)
                        .opacity(animate ? 0 : 1)
                }
            }
            .onAppear { animate = pulsing }
            .animation(
                pulsing ? .easeOut(duration: 1.3).repeatForever(autoreverses: false) : .default,
                value: animate
            )
    }
}

struct TagView: View {
    var text: String
    var symbol: String? = nil
    var tint: Color = .nIcon
    var filled = false

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 8.5, weight: .semibold))
            }
            Text(text)
                .font(.nCaption)
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(
            Capsule(style: .continuous)
                .fill(filled ? tint.opacity(0.13) : Color.primary.opacity(0.035))
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(tint.opacity(filled ? 0.22 : 0.11), lineWidth: 0.7)
        }
    }
}

struct KeyboardKey: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 9.5, weight: .medium, design: .rounded))
            .foregroundStyle(Color.nTextSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.nHairline, lineWidth: 0.6)
            }
    }
}

struct SearchInput: View {
    @Binding var text: String
    var placeholder = "Search"

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.nTextTertiary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.nSmall)
                .focused($focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.nTextTertiary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.nSurfaceSunken.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(focused ? Color.nAccent.opacity(0.45) : Color.nHairline, lineWidth: 0.8)
        }
        .animation(.quick, value: focused)
    }
}

struct SectionLabel: View {
    let text: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(Color.nTextTertiary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.nCaption)
                    .foregroundStyle(Color.nTextTertiary)
            }
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.nAccentSoft)
                    .frame(width: 44, height: 44)
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.nAccent)
            }
            Text(title)
                .font(.nHeadline)
                .foregroundStyle(Color.nTextPrimary)
            Text(message)
                .font(.nSmall)
                .foregroundStyle(Color.nTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct Spinner: View {
    @State private var rotating = false

    var body: some View {
        Circle()
            .trim(from: 0.15, to: 0.85)
            .stroke(Color.nAccent, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    rotating = true
                }
            }
            .accessibilityLabel("Loading")
    }
}

struct HoverHighlight: ViewModifier {
    var radius: CGFloat = 12
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(hovered ? Color.primary.opacity(0.045) : .clear)
            )
            .onHover { hovered = $0 }
            .animation(.quick, value: hovered)
    }
}

extension View {
    func hoverHighlight(radius: CGFloat = 12) -> some View {
        modifier(HoverHighlight(radius: radius))
    }
}
