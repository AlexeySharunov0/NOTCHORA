import NotchoraCore
import SwiftUI

struct NotchoraMark: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.nAccent, Color.nTeal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.7)
                }

            Image(systemName: "sparkles")
                .font(.system(size: size * 0.47, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.96))
                .frame(width: size, height: size)
                .offset(y: size * 0.05)

            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.88))
                .frame(width: size * 0.42, height: size * 0.115)
                .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct NotchoraWordmark: View {
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            NotchoraMark(size: compact ? 16 : 20)
            Text("NOTCHORA")
                .font(.system(size: compact ? 9.5 : 10.5, weight: .bold))
                .tracking(compact ? 0.9 : 1.2)
                .foregroundStyle(Color.white.opacity(0.94))
        }
    }
}

struct ProviderMiniRow: View {
    let provider: AIProviderID
    let hasKey: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ProviderGlyph(provider: provider, size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.displayName)
                        .font(.nSmallMedium)
                        .foregroundStyle(Color.nTextPrimary)
                    Text(hasKey ? "Connected" : "Add API key")
                        .font(.nCaptionRegular)
                        .foregroundStyle(hasKey ? Color.nSuccess : Color.nTextTertiary)
                }
                Spacer()
                Image(systemName: hasKey ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(hasKey ? Color.nSuccess : Color.nTextTertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .background(Color.black)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.quick, value: hovered)
    }
}
