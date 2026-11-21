import AppKit
import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

struct NPanelBackground: View {
    var transparent: Bool = true
    var body: some View {
        ZStack {
            if transparent {
                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                Color.nPanel.opacity(0.62)
            } else {
                Color.nPanelSolid
            }
        }
    }
}

struct NotchBottomShape: Shape {
    var radius: CGFloat = Metric.compactRadius

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

struct NotchSurfaceShape: Shape {
    var topRadius: CGFloat = 20
    var bottomRadius: CGFloat = Metric.panelRadius

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: topRadius,
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            topTrailingRadius: topRadius,
            style: .continuous
        ).path(in: rect)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.nHairline)
            .frame(height: 1)
    }
}

struct SurfaceBorder: View {
    var radius: CGFloat = Metric.panelRadius
    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.16), Color.nHairline.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.8
            )
    }
}

struct AmbientGlow: View {
    var color: Color = .nAccent
    var body: some View {
        RadialGradient(
            colors: [color.opacity(0.10), color.opacity(0.025), .clear],
            center: .topLeading,
            startRadius: 4,
            endRadius: 340
        )
        .allowsHitTesting(false)
    }
}

struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18
            let dot = Path(ellipseIn: CGRect(x: 0, y: 0, width: 1.2, height: 1.2))
            for x in stride(from: 0, through: size.width, by: spacing) {
                for y in stride(from: 0, through: size.height, by: spacing) {
                    context.fill(dot.offsetBy(dx: x, dy: y), with: .color(Color.nHairline.opacity(0.45)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
