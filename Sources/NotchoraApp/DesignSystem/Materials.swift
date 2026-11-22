import SwiftUI

/// The only shape used by the notch surface. It is deliberately just a black
/// form with a welded top edge and rounded lower corners: no material, glow,
/// border, or glass layer is involved.
struct NotchSurfaceShape: Shape {
    var topRadius: CGFloat = 0
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
            .fill(Color(white: 0.16))
            .frame(height: 0.7)
    }
}
