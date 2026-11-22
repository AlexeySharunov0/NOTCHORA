import SwiftUI

struct VoiceWaveform: View {
    let levels: [Float]
    let phase: VoicePhase
    var color: Color = .nAccent
    var height: CGFloat = 64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || phase == .idle)) { timeline in
            Canvas { context, size in
                let count = max(levels.count, 12)
                let spacing: CGFloat = 3
                let barWidth = max(1.5, (size.width - CGFloat(count - 1) * spacing) / CGFloat(count))
                let midY = size.height / 2
                let time = timeline.date.timeIntervalSinceReferenceDate
                let activeColor = phase == .error ? Color.nDanger : color

                for index in 0..<count {
                    let sourceIndex = min(index, max(0, levels.count - 1))
                    let base = CGFloat(levels.isEmpty ? 0 : levels[sourceIndex])
                    let synthetic: CGFloat
                    switch phase {
                    case .listening:
                        synthetic = 0
                    case .processing:
                        synthetic = (sin(time * 2.4 + Double(index) * 0.35) + 1) * 0.05
                    case .responding:
                        synthetic = (sin(time * 5.0 + Double(index) * 0.55) + 1) * 0.13
                    case .interrupted, .error:
                        synthetic = 0.03
                    default:
                        synthetic = 0
                    }
                    let amplitude = max(0.035, base * 0.9 + synthetic)
                    let barHeight = min(size.height, max(3, amplitude * size.height))
                    let x = CGFloat(index) * (barWidth + spacing)
                    let rect = CGRect(
                        x: x,
                        y: midY - barHeight / 2,
                        width: barWidth,
                        height: barHeight
                    )
                    let opacity = phase == .idle ? 0.22 : 0.35 + Double(amplitude) * 0.65
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(activeColor.opacity(min(opacity, 1)))
                    )
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct CompactWaveform: View {
    var color: Color = .nAccent
    var active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !active || reduceMotion)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let count = 4
                let barWidth: CGFloat = 2
                let spacing: CGFloat = 2
                let total = CGFloat(count) * barWidth + CGFloat(count - 1) * spacing
                for index in 0..<count {
                    let wave = (sin(time * 6 + Double(index) * 1.1) + 1) / 2
                    let barHeight = active ? 4 + CGFloat(wave) * (size.height - 5) : 3
                    let rect = CGRect(
                        x: (size.width - total) / 2 + CGFloat(index) * (barWidth + spacing),
                        y: (size.height - barHeight) / 2,
                        width: barWidth,
                        height: barHeight
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 1),
                        with: .color(color.opacity(active ? 0.75 : 0.4))
                    )
                }
            }
            .frame(width: 16, height: 12)
        }
    }
}
