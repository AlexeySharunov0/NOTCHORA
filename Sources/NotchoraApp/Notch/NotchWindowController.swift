import AppKit
import QuartzCore
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
            panel.orderOut(nil)
            return
        case .compact:
            panel.hasShadow = false
            let wasOpen = old == .expanded || old == .workspace
            let target = currentFrame(for: .compact)
            setFrame(target, animated: animated && old != .compact)
            panel.orderFront(nil)
            panel.resignKey()
            if wasOpen, NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier,
               let previousPID = model.previousFrontmostPID,
               let previous = NSRunningApplication(processIdentifier: previousPID) {
                previous.activate()
            }
        case .expanded, .workspace:
            panel.hasShadow = presentation == .workspace
            let target = currentFrame(for: presentation)
            if old == .compact || old == .hidden {
                let frontmost = NSWorkspace.shared.frontmostApplication
                if let frontmost, frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                    model.previousFrontmostPID = frontmost.processIdentifier
                }
                panel.alphaValue = 0.96
            }
            setFrame(target, animated: animated)
            panel.orderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
            panel.alphaValue = 1
        }
    }

    func refreshForScreenChange() {
        positionOnPreferredScreen()
        guard currentPresentation != .hidden else { return }
        panel.setFrame(currentFrame(for: currentPresentation), display: true)
    }

    func snapToCurrentScreen() {
        positionOnPreferredScreen()
        guard currentPresentation != .hidden else { return }
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

    private func setFrame(_ frame: CGRect, animated: Bool) {
        guard frame != panel.frame else { return }
        if !animated || !model.settings.animationsEnabled || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrame(frame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.34
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
            panel.animator().setFrame(frame, display: true)
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
        guard !model.voicePresented, !model.isCapturingScreen, !model.isTransientUIPresented, !model.suppressAutoCollapseForQA else { return }
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
