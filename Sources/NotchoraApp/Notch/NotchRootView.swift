import NotchoraCore
import SwiftUI

struct NotchRootView: View {
    let model: AppModel
    let environment: NotchEnvironment

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            switch model.presentation {
            case .hidden:
                EmptyView()
            case .compact:
                CompactNotchView(model: model, environment: environment)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .expanded:
                ExpandedNotchView(model: model, environment: environment)
                    .transition(.opacity)
            case .workspace:
                WorkspaceView(model: model)
                    .transition(.opacity)
            }

            if model.voicePresented {
                VoiceOverlay(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    .zIndex(20)
            }

            if let offer = model.selectedTextOffer {
                SelectionActionOverlay(model: model, offer: offer)
                    .zIndex(30)
            }

            if let failure = model.selectionFailure {
                SelectionFailureOverlay(model: model, failure: failure)
                    .zIndex(30)
            }

            if let toast = model.toast, model.presentation != .compact {
                VStack {
                    Spacer()
                    ToastView(model: model, toast: toast)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(Color.nAccent)
        .preferredColorScheme(model.settings.appearance.colorScheme)
        .onExitCommand(perform: handleEscape)
        .sheet(isPresented: handoffBinding) {
            HandoffSheet(model: model)
        }
        .sheet(isPresented: systemPromptBinding) {
            SystemPromptSheet(model: model)
        }
        .sheet(isPresented: screenCaptureBinding) {
            ScreenCapturePickerSheet(model: model)
        }
        .animation(.easeOut(duration: 0.2), value: model.toast?.id)
    }

    private var handoffBinding: Binding<Bool> {
        Binding(
            get: { model.isHandoffPresented },
            set: { model.isHandoffPresented = $0 }
        )
    }

    private var systemPromptBinding: Binding<Bool> {
        Binding(
            get: { model.isSystemPromptPresented },
            set: { model.isSystemPromptPresented = $0 }
        )
    }

    private var screenCaptureBinding: Binding<Bool> {
        Binding(
            get: { model.isScreenCapturePickerPresented },
            set: { model.isScreenCapturePickerPresented = $0 }
        )
    }

    private func handleEscape() {
        if model.selectedTextOffer != nil {
            model.dismissSelectionOffer()
        } else if model.selectionFailure != nil {
            model.dismissSelectionFailure()
        } else if model.voicePresented {
            model.stopVoiceMode()
        } else if model.presentation == .workspace {
            model.setPresentation(.expanded)
        } else {
            model.collapse()
        }
    }
}

struct CompactNotchView: View {
    let model: AppModel
    let environment: NotchEnvironment

    @State private var hovered = false
    @State private var hoverTask: Task<Void, Never>?

    private var isGenerating: Bool { model.isGeneratingCurrent }
    private var hasTasks: Bool { model.runningTaskCount > 0 }

    var body: some View {
        Group {
            if environment.hasPhysicalNotch {
                physicalNotch
            } else {
                fallbackPill
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            model.openPanel()
        }
        .onHover { hovering in
            hovered = hovering
            hoverTask?.cancel()
            guard hovering, model.settings.hoverToExpand else { return }
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(260))
                guard !Task.isCancelled, model.presentation == .compact else { return }
                model.openPanel()
            }
        }
        .help("Open NOTCHORA · \(model.settings.binding(for: .openPanel)?.combo.displayString ?? "⌥Space")")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("NOTCHORA. Open AI panel.")
        .accessibilityAddTraits(.isButton)
        .onDisappear { hoverTask?.cancel() }
    }

    private var physicalNotch: some View {
        GeometryReader { proxy in
            let ear = max(18, (proxy.size.width - environment.notchWidth) / 2)
            HStack(spacing: 0) {
                HStack(spacing: 5) {
                    NotchoraMark(size: 14)
                        .opacity(hovered ? 1 : 0.82)
                    if hasTasks {
                        Text("\(model.runningTaskCount)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.nWarning)
                    }
                }
                .frame(width: ear)

                Color.clear
                    .frame(width: environment.notchWidth)

                HStack(spacing: 3) {
                    if isGenerating {
                        CompactWaveform(color: .nAccent, active: true)
                    } else if hasTasks {
                        StatusDot(color: .nWarning, pulsing: true)
                    } else {
                        Image(systemName: hovered ? "chevron.down" : "circle.fill")
                            .font(.system(size: hovered ? 8 : 3, weight: .bold))
                            .foregroundStyle(Color.white.opacity(hovered ? 0.65 : 0.32))
                    }
                }
                .frame(width: ear)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background {
            ZStack {
                Color.nRail
                if hovered {
                    RadialGradient(
                        colors: [Color.nAccent.opacity(0.17), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 120
                    )
                }
            }
        }
        .clipShape(NotchBottomShape(radius: 12))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.7)
        }
    }

    private var fallbackPill: some View {
        HStack(spacing: 7) {
            NotchoraMark(size: 15)
            Text("NOTCHORA")
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(Color.white.opacity(0.9))
            Spacer(minLength: 4)
            if isGenerating {
                CompactWaveform(color: .nAccent, active: true)
            } else if hasTasks {
                StatusDot(color: .nWarning, pulsing: true)
            }
            Text(model.settings.binding(for: .openPanel)?.combo.displayString ?? "⌥Space")
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color.nRail
                if hovered {
                    Color.white.opacity(0.04)
                }
            }
        }
        .clipShape(Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.7)
        }
        .padding(.horizontal, 1)
    }
}

struct ExpandedNotchView: View {
    let model: AppModel
    let environment: NotchEnvironment

    var body: some View {
        VStack(spacing: 0) {
            ExpandedRail(model: model, environment: environment)

            ZStack {
                NPanelBackground(transparent: model.settings.transparencyEnabled)
                AmbientGlow(color: .nAccent)
                    .opacity(0.55)
                routeContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.nRail)
        .clipShape(NotchSurfaceShape(
            topRadius: environment.hasPhysicalNotch ? 0 : 24,
            bottomRadius: Metric.panelRadius
        ))
        .overlay {
            NotchSurfaceShape(
                topRadius: environment.hasPhysicalNotch ? 0 : 24,
                bottomRadius: Metric.panelRadius
            )
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(environment.hasPhysicalNotch ? 0.02 : 0.16),
                        Color.nHairline.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.8
            )
        }
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(Color.primary.opacity(0.16))
                .frame(width: 62, height: 3)
                .padding(.bottom, 4)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var routeContent: some View {
        switch model.route {
        case .chat:
            ChatView(model: model)
        case .history:
            HistoryView(model: model)
        case .tasks:
            TasksView(model: model)
        case .apps:
            AppsView(model: model)
        case .workflows:
            WorkflowsView(model: model)
        case .multiAI:
            MultiAIView(model: model)
        }
    }
}

struct ExpandedRail: View {
    let model: AppModel
    let environment: NotchEnvironment

    private var railHeight: CGFloat {
        environment.hasPhysicalNotch ? max(environment.topRailHeight, 37) : 40
    }

    var body: some View {
        GeometryReader { proxy in
            if environment.hasPhysicalNotch {
                let ear = max(80, (proxy.size.width - environment.notchWidth) / 2)
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        NotchoraWordmark()
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 13)
                    .frame(width: ear)

                    Color.clear
                        .frame(width: environment.notchWidth)

                    HStack(spacing: 1) {
                        Spacer(minLength: 0)
                        railButtons
                    }
                    .padding(.trailing, 8)
                    .frame(width: ear)
                }
            } else {
                HStack(spacing: 0) {
                    NotchoraWordmark()
                        .padding(.leading, 13)
                    Spacer()
                    railButtons
                        .padding(.trailing, 8)
                }
            }
        }
        .frame(height: railHeight)
        .background(Color.nRail)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 0.7)
        }
    }

    private var railButtons: some View {
        HStack(spacing: 1) {
            RailButton(
                symbol: "clock.arrow.circlepath",
                label: "History",
                active: model.route == .history
            ) { model.navigate(.history) }

            RailButton(
                symbol: "checklist",
                label: "Tasks",
                active: model.route == .tasks,
                badge: model.runningTaskCount
            ) { model.navigate(.tasks) }

            RailButton(
                symbol: "square.split.2x2",
                label: "Multi-AI",
                active: model.route == .multiAI
            ) { model.openMultiAISetup() }

            RailMenuButton(model: model)

            RailButton(
                symbol: "arrow.up.left.and.arrow.down.right",
                label: "Full Workspace",
                active: false
            ) { model.setPresentation(.workspace) }

            RailButton(
                symbol: "chevron.down",
                label: "Collapse",
                active: false
            ) { model.collapse() }
        }
    }
}

struct RailButton: View {
    let symbol: String
    let label: String
    var active = false
    var badge: Int = 0
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(active ? Color.white.opacity(0.95) : Color.white.opacity(hovered ? 0.80 : 0.48))
                    .frame(width: 22, height: 23)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(active ? Color.white.opacity(0.12) : (hovered ? Color.white.opacity(0.06) : .clear))
                    )
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.nRail)
                        .padding(.horizontal, 3)
                        .frame(minWidth: 10, minHeight: 10)
                        .background(Circle().fill(Color.nWarning))
                        .offset(x: 3, y: -3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .onHover { hovered = $0 }
        .animation(.quick, value: hovered)
    }
}


struct RailMenuButton: View {
    let model: AppModel
    @State private var hovered = false

    var body: some View {
        Menu {
            Button {
                model.navigate(.apps)
            } label: {
                Label("AI Apps", systemImage: "square.grid.2x2")
            }
            Button {
                model.navigate(.workflows)
            } label: {
                Label("Workflows", systemImage: "point.3.connected.trianglepath.dotted")
            }
            Divider()
            Button {
                model.requestSettings(.general)
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(hovered ? 0.80 : 0.48))
                .frame(width: 22, height: 23)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hovered ? Color.white.opacity(0.06) : .clear)
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
        .accessibilityLabel("More")
        .onHover { hovered = $0 }
        .animation(.quick, value: hovered)
    }
}
