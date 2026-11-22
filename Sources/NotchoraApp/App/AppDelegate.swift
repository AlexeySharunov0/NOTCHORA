import AppKit
import NotchoraCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppEnvironment.shared.model
    private var notchController: NotchWindowController?
    private var statusBarController: StatusBarController?
    private var hotKeyManager: GlobalHotKeyManager?
    private var terminationPending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureAppearance()
        configureModelCallbacks()
        notchController = NotchWindowController(model: model)
        notchController?.showInitialPanel()
        statusBarController = StatusBarController(model: model)
        statusBarController?.setVisible(model.settings.showMenuBarItem)
        configureHotKeys()
        model.bootstrap()
        if model.settings.launchAtLogin {
            try? LaunchAtLoginService.setEnabled(true)
        }

        // A menu bar utility should not steal the menu bar when it launches
        // straight into its idle notch state (for example at login).
        Task {
            try? await Task.sleep(for: .milliseconds(1_200))
            if model.presentation == .compact,
               NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
                NSApp.deactivate()
            }
        }

        #if DEBUG
        QAHarness.runIfNeeded(model: model, panel: notchController?.qaPanel)
        #endif

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model.permissions.refresh()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.openPanel()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationPending else { return .terminateNow }
        terminationPending = true
        Task {
            await model.flush()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    @objc private func screenParametersChanged() {
        notchController?.refreshForScreenChange()
    }

    private func configureModelCallbacks() {
        model.presentationDidChange = { [weak self] presentation, animated in
            self?.notchController?.apply(presentation, animated: animated)
        }
        model.menuBarVisibilityChanged = { [weak self] visible in
            self?.statusBarController?.setVisible(visible)
        }
        model.shortcutsChanged = { [weak self] bindings in
            self?.registerShortcuts(bindings)
        }
        model.shortcutsRegistrationRequested = { [weak self] bindings in
            self?.registerShortcuts(bindings)
        }
        model.appearanceChanged = { [weak self] appearance in
            self?.applyAppearance(appearance)
        }
    }

    private func configureAppearance() {
        applyAppearance(model.settings.appearance)
    }

    private func applyAppearance(_ appearance: AppAppearance) {
        switch appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        notchController?.rebuildContent()
    }

    private func configureHotKeys() {
        let manager = GlobalHotKeyManager()
        manager.onAction = { action in
            Task { @MainActor in
                AppEnvironment.shared.model.handleGlobalShortcut(action)
            }
        }
        hotKeyManager = manager
        registerShortcuts(model.settings.shortcuts)
    }

    private func registerShortcuts(_ bindings: [ShortcutBinding]) {
        guard let hotKeyManager else { return }
        model.shortcutRegistrationErrors = hotKeyManager.update(bindings: bindings)
    }

}
