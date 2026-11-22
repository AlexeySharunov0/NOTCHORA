import NotchoraCore
import SwiftUI

/// The notch is represented by one SwiftUI surface whose bottom edge and side
/// edges grow while its top edge stays welded to the physical display cutout.
/// There is no second window, material, border, or translucent backdrop: the
/// only visible fill is opaque black.
struct NotchRootView: View {
    let model: AppModel
    let environment: NotchEnvironment

    @State private var revealContent = true
    @State private var revealTask: Task<Void, Never>?
    @State private var displayedSurfaceSize: CGSize = .zero
    @State private var isCollapsingToCompact = false
    @State private var collapseTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var renderedSurfaceSize: CGSize {
        displayedSurfaceSize == .zero ? targetSurfaceSize : displayedSurfaceSize
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if model.presentation != .hidden {
                    ZStack {
                        Color.black
                        surface
                    }
                    .frame(width: renderedSurfaceSize.width, height: renderedSurfaceSize.height)
                    .clipShape(surfaceShape)
                    .position(
                        x: proxy.size.width / 2,
                        y: renderedSurfaceSize.height / 2
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .tint(Color.nAccent)
        .preferredColorScheme(.dark)
        .onExitCommand(perform: handleEscape)
        .onAppear {
            displayedSurfaceSize = targetSurfaceSize
            scheduleReveal(for: model.presentation, immediate: true)
        }
        .onChange(of: model.presentation) { old, presentation in
            animateSurface(to: NotchGeometry.surfaceSize(for: presentation, environment: environment))
            scheduleReveal(for: presentation, immediate: false)

            collapseTask?.cancel()
            if presentation == .compact,
               (old == .expanded || old == .workspace),
               model.presentationAnimationEnabled,
               model.settings.animationsEnabled,
               !reduceMotion {
                isCollapsingToCompact = true
                collapseTask = Task {
                    try? await Task.sleep(for: .milliseconds(360))
                    guard !Task.isCancelled else { return }
                    isCollapsingToCompact = false
                }
            } else {
                isCollapsingToCompact = false
            }
        }
        .onChange(of: environment.screenWidth) { _, _ in
            displayedSurfaceSize = targetSurfaceSize
        }
        .onChange(of: environment.screenHeight) { _, _ in
            displayedSurfaceSize = targetSurfaceSize
        }
        .onChange(of: environment.notchWidth) { _, _ in
            displayedSurfaceSize = targetSurfaceSize
        }
        .onDisappear {
            revealTask?.cancel()
            collapseTask?.cancel()
        }
    }

    @ViewBuilder
    private var surface: some View {
        switch model.presentation {
        case .hidden:
            Color.clear
        case .compact:
            if isCollapsingToCompact {
                Color.clear
            } else {
                CompactNotchView(model: model, environment: environment)
                    .background(Color.black)
                    .transition(.identity)
            }
        case .expanded:
            ExpandedNotchView(
                model: model,
                environment: environment,
                workspace: false,
                revealContent: revealContent
            )
            .transition(.identity)
        case .workspace:
            ExpandedNotchView(
                model: model,
                environment: environment,
                workspace: true,
                revealContent: revealContent
            )
            .transition(.identity)
        }
    }

    private var targetSurfaceSize: CGSize {
        NotchGeometry.surfaceSize(for: model.presentation, environment: environment)
    }

    private var surfaceAnimation: Animation? {
        guard model.presentationAnimationEnabled, model.settings.animationsEnabled, !reduceMotion else {
            return nil
        }
        return .spring(response: 0.5, dampingFraction: 0.84, blendDuration: 0.14)
    }

    private func animateSurface(to target: CGSize) {
        if let surfaceAnimation {
            withAnimation(surfaceAnimation) {
                displayedSurfaceSize = target
            }
        } else {
            displayedSurfaceSize = target
        }
    }

    private var surfaceShape: NotchSurfaceShape {
        if model.presentation == .compact {
            return NotchSurfaceShape(
                topRadius: environment.hasPhysicalNotch ? 0 : 17,
                bottomRadius: 17
            )
        }
        return NotchSurfaceShape(
            topRadius: environment.hasPhysicalNotch ? 0 : 24,
            bottomRadius: 28
        )
    }

    private func scheduleReveal(for presentation: PanelPresentation, immediate: Bool) {
        revealTask?.cancel()
        guard presentation == .expanded || presentation == .workspace else {
            revealContent = false
            return
        }
        if !model.presentationAnimationEnabled || !model.settings.animationsEnabled || reduceMotion {
            revealContent = true
            return
        }
        revealContent = false
        revealTask = Task {
            try? await Task.sleep(for: .milliseconds(immediate ? 120 : 140))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.24)) { revealContent = true }
        }
    }

    private func handleEscape() {
        if model.isHandoffPresented {
            model.isHandoffPresented = false
        } else if model.isSystemPromptPresented {
            model.isSystemPromptPresented = false
        } else if model.isScreenCapturePickerPresented {
            model.isScreenCapturePickerPresented = false
        } else if model.isModelPickerPresented {
            model.isModelPickerPresented = false
        } else if model.selectedTextOffer != nil {
            model.dismissSelectionOffer()
        } else if model.selectionFailure != nil {
            model.dismissSelectionFailure()
        } else if model.voicePresented {
            model.stopVoiceMode()
        } else if model.presentation == .workspace {
            if model.route == .settings {
                model.collapse()
            } else {
                model.setPresentation(.expanded)
            }
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
        .onTapGesture { model.openPanel() }
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
        .accessibilityLabel("NOTCHORA. Open AI control center.")
        .accessibilityAddTraits(.isButton)
        .onDisappear { hoverTask?.cancel() }
    }

    /// The hardware notch is already black; the window only adds a few points
    /// of clickable black around it and a tiny activity line at the lower edge.
    private var physicalNotch: some View {
        ZStack(alignment: .bottom) {
            Color.black
            Group {
                if hovered {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.55))
                } else if isGenerating {
                    CompactWaveform(color: .nAccent, active: true)
                } else if hasTasks {
                    StatusDot(color: .nWarning, pulsing: true)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 9, height: 2)
                }
            }
            .frame(height: 12, alignment: .center)
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .foregroundStyle(Color.white.opacity(0.42))
        }
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct ExpandedNotchView: View {
    let model: AppModel
    let environment: NotchEnvironment
    let workspace: Bool
    let revealContent: Bool

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 0) {
                ExpandedRail(model: model, environment: environment, workspace: workspace)

                ZStack {
                    if workspace {
                        if model.route == .settings {
                            SettingsRootView(model: model, embedded: true)
                        } else {
                            WorkspaceView(model: model)
                        }
                    } else {
                        RouteContentView(model: model, workspace: false)
                    }

                    contentOverlays
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .opacity(revealContent ? 1 : 0)
            .allowsHitTesting(revealContent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    @ViewBuilder
    private var contentOverlays: some View {
        if model.isModelPickerPresented {
            ModelPickerOverlay(model: model)
                .zIndex(10)
        }
        if model.voicePresented {
            VoiceOverlay(model: model)
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
        if model.isHandoffPresented {
            HandoffOverlay(model: model)
                .zIndex(40)
        }
        if model.isSystemPromptPresented {
            SystemPromptOverlay(model: model)
                .zIndex(40)
        }
        if model.isScreenCapturePickerPresented {
            ScreenCaptureOverlay(model: model)
                .zIndex(40)
        }
        if let toast = model.toast {
            VStack {
                Spacer()
                ToastView(model: model, toast: toast)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(50)
        }
    }
}

struct RouteContentView: View {
    let model: AppModel
    var workspace: Bool

    var body: some View {
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
        case .settings:
            SettingsRootView(model: model, embedded: true)
        }
    }
}

struct ExpandedRail: View {
    let model: AppModel
    let environment: NotchEnvironment
    var workspace: Bool

    private var railHeight: CGFloat {
        environment.hasPhysicalNotch ? max(environment.topRailHeight, 37) : 40
    }

    var body: some View {
        GeometryReader { proxy in
            if environment.hasPhysicalNotch {
                let side = max(80, (proxy.size.width - environment.notchWidth) / 2)
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        NotchoraWordmark()
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 13)
                    .frame(width: side)

                    Color.black
                        .frame(width: environment.notchWidth)

                    HStack(spacing: 1) {
                        Spacer(minLength: 0)
                        railButtons
                    }
                    .padding(.trailing, 8)
                    .frame(width: side)
                }
            } else {
                HStack(spacing: 0) {
                    NotchoraWordmark().padding(.leading, 13)
                    Spacer()
                    railButtons.padding(.trailing, 8)
                }
            }
        }
        .frame(height: railHeight)
        .background(Color.black)
    }

    private var railButtons: some View {
        HStack(spacing: 1) {
            RailButton(
                symbol: "bubble.left.and.bubble.right",
                label: "Chat",
                active: model.route == .chat
            ) { model.navigate(.chat) }

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

            if model.route != .settings {
                RailButton(
                    symbol: workspace ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                    label: workspace ? "Compact Workspace" : "Full Workspace",
                    active: workspace
                ) {
                    model.setPresentation(workspace ? .expanded : .workspace)
                }
            }

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
                    .foregroundStyle(active ? Color.white : Color.white.opacity(hovered ? 0.78 : 0.44))
                    .frame(width: 22, height: 23)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 3)
                        .frame(minWidth: 10, minHeight: 10)
                        .background(Circle().fill(Color.nWarning))
                        .offset(x: 3, y: -3)
                }
                if active {
                    Capsule()
                        .fill(Color.nAccent)
                        .frame(width: 11, height: 2)
                        .offset(y: 10)
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
            Button { model.navigate(.apps) } label: {
                Label("AI Apps", systemImage: "square.grid.2x2")
            }
            Button { model.navigate(.workflows) } label: {
                Label("Workflows", systemImage: "point.3.connected.trianglepath.dotted")
            }
            Button { model.requestSettings(.general) } label: {
                Label("Settings…", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(hovered ? 0.78 : 0.44))
                .frame(width: 22, height: 23)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
        .accessibilityLabel("More")
        .onHover { hovered = $0 }
    }
}
