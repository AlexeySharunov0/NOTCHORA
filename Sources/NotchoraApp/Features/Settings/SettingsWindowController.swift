import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NOTCHORA Settings"
        window.minSize = NSSize(width: 780, height: 560)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenAuxiliary]
        #if DEBUG
        if ProcessInfo.processInfo.environment["NOTCHORA_QA"] != "1" {
            window.setFrameAutosaveName("NotchoraSettingsWindow")
        }
        #else
        window.setFrameAutosaveName("NotchoraSettingsWindow")
        #endif
        window.contentViewController = NSHostingController(
            rootView: SettingsRootView(model: model)
        )
        window.setContentSize(NSSize(width: 900, height: 660))
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(tab: SettingsTab) {
        model.settingsTabRequest = tab
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // The controller stays alive so reopening preserves the last tab and
        // window position. No background work depends on this window.
    }
}
