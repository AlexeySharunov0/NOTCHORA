import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class NotchWindowController: NSWindowController, NSWindowDelegate {
    private let model: AppModel
    private let environment = NotchEnvironment()
    private let panel: NotchPanel
    private var currentPresentation: PanelPresentation = .compact
    private var currentScreen: NSScreen
    private var hasWindow = false
    private var containerTask: Task<Void, Never>?
    private var pointerMonitor: Any?
    private var hoverOpenTask: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
        let screen = NotchGeometry.preferredScreen(settings: model.settings)
        self.currentScreen = screen
        environment.update(for: screen)

        let frame = NotchGeometry.frame(for: .compact, on: screen)
        panel = NotchPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // The window is only a hit-test container. The visible notch surface is
        // drawn as one opaque black SwiftUI shape; non-opaque is required only
        // so the rounded lower corners can reveal the desktop.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .none
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.worksWhenModal = true

        let root = NotchRootView(model: model, environment: environment)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        super.init(window: panel)
        panel.delegate = self
    }

    /// The compact surface is exactly the hardware cutout, so there are no
    /// software pixels to click. Observe only the pointer position in a small
    /// invisible zone around the cutout, and only while compact.
    private func startPointerMonitor() {
        guard pointerMonitor == nil else { return }
        pointerMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .mouseMoved]
        ) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handlePointer(event)
            }
        }
    }

    private func stopPointerMonitor() {
        if let pointerMonitor {
            NSEvent.removeMonitor(pointerMonitor)
            self.pointerMonitor = nil
        }
        hoverOpenTask?.cancel()
        hoverOpenTask = nil
    }

    private func handlePointer(_ event: NSEvent) {
        guard currentPresentation == .compact, hasWindow else { return }
        let point = NSEvent.mouseLocation
        let frame = currentScreen.frame
        let height = max(environment.topRailHeight, NotchGeometry.compactHeightWithNotch)
        let hotZone = NSRect(
            x: frame.midX - environment.notchWidth / 2 - 10,
            y: frame.maxY - height - 3,
            width: environment.notchWidth + 20,
            height: height + 5
        )
        guard hotZone.contains(point) else {
            hoverOpenTask?.cancel()
            hoverOpenTask = nil
            return
        }

        if event.type == .leftMouseDown {
            hoverOpenTask?.cancel()
            hoverOpenTask = nil
            model.openPanel()
            return
        }

        guard model.settings.hoverToExpand, hoverOpenTask == nil else { return }
        hoverOpenTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard let self, !Task.isCancelled, self.currentPresentation == .compact else { return }
            self.hoverOpenTask = nil
            self.model.openPanel()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showInitialPanel() {
        guard !hasWindow else { return }
        hasWindow = true
        positionOnPreferredScreen()
        panel.setFrame(currentFrame(for: .compact), display: true)
        panel.orderFront(nil)
        currentPresentation = .compact
        startPointerMonitor()
    }

    func apply(_ presentation: PanelPresentation, animated: Bool = true) {
        guard hasWindow else {
            showInitialPanel()
            return
        }
        if presentation != .hidden {
            positionOnPreferredScreen()
        }
        let old = currentPresentation
        currentPresentation = presentation

        switch presentation {
        case .hidden:
            stopPointerMonitor()
            containerTask?.cancel()
            panel.ignoresMouseEvents = false
            panel.setFrame(currentFrame(for: .compact), display: false)
            panel.orderOut(nil)
            return
        case .compact:
            startPointerMonitor()
            let wasOpen = old == .expanded || old == .workspace
            transition(to: currentFrame(for: .compact), animated: animated && old != .compact)
            panel.orderFront(nil)
            panel.resignKey()
            if wasOpen, NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier,
               let previousPID = model.previousFrontmostPID,
               let previous = NSRunningApplication(processIdentifier: previousPID) {
                previous.activate()
            }
        case .expanded, .workspace:
            stopPointerMonitor()
            if old == .compact || old == .hidden {
                let frontmost = NSWorkspace.shared.frontmostApplication
                if let frontmost, frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                    model.previousFrontmostPID = frontmost.processIdentifier
                }
            }
            transition(to: currentFrame(for: presentation), animated: animated)
            panel.orderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
        }
    }

    func refreshForScreenChange() {
        containerTask?.cancel()
        positionOnPreferredScreen()
        guard currentPresentation != .hidden else { return }
        panel.ignoresMouseEvents = false
        panel.setFrame(currentFrame(for: currentPresentation), display: true)
    }

    func snapToCurrentScreen() {
        containerTask?.cancel()
        positionOnPreferredScreen()
        guard currentPresentation != .hidden else { return }
        panel.ignoresMouseEvents = false
        panel.setFrame(currentFrame(for: currentPresentation), display: true)
    }

    private func positionOnPreferredScreen() {
        let screen = NotchGeometry.preferredScreen(settings: model.settings)
        currentScreen = screen
        environment.update(for: screen)
    }

    private func currentFrame(for presentation: PanelPresentation) -> CGRect {
        NotchGeometry.frame(for: presentation, on: currentScreen)
    }

    /// The window is only a transparent container. SwiftUI animates the black
    /// surface itself; this method gives the surface enough room while it grows
    /// and then trims the invisible container after the spring settles.
    private func transition(to target: CGRect, animated: Bool) {
        containerTask?.cancel()

        let shouldAnimate = animated
            && model.settings.animationsEnabled
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        guard shouldAnimate else {
            panel.ignoresMouseEvents = false
            panel.setFrame(target, display: true)
            return
        }

        let current = panel.frame
        let width = max(current.width, target.width)
        let height = max(current.height, target.height)
        let top = max(current.maxY, target.maxY)
        let container = CGRect(
            x: currentScreen.frame.midX - width / 2,
            y: top - height,
            width: width,
            height: height
        )
        if panel.frame != container {
            panel.setFrame(container, display: true)
        }

        // The transparent part of the container must never swallow clicks.
        panel.ignoresMouseEvents = target.width < container.width || target.height < container.height
        let expected = currentPresentation
        containerTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard let self, !Task.isCancelled, self.currentPresentation == expected else { return }
            self.panel.setFrame(target, display: true)
            self.panel.ignoresMouseEvents = false
        }
    }

    func rebuildContent() {
        let frame = panel.contentView?.bounds ?? NSRect(origin: .zero, size: panel.frame.size)
        let wasKey = panel.isKeyWindow
        let root = NotchRootView(model: model, environment: environment)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = frame
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        if wasKey {
            panel.makeKey()
        }
    }

    #if DEBUG
    var qaPanel: NSWindow { panel }
    #endif

    func windowDidResignKey(_ notification: Notification) {
        guard currentPresentation == .expanded || currentPresentation == .workspace else { return }
        guard !model.voicePresented, !model.isCapturingScreen, !model.suppressAutoCollapseForQA else { return }
        if panel.attachedSheet != nil { return }
        if let key = NSApp.keyWindow,
           key !== panel,
           key.sheetParent === panel {
            return
        }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(140))
            guard let self, !self.panel.isKeyWindow else { return }
            guard self.currentPresentation == .expanded || self.currentPresentation == .workspace else { return }
            if self.panel.attachedSheet != nil { return }
            self.model.collapse()
        }
    }
}
