import AppKit
import NotchoraCore

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let tasksItem = NSMenuItem(title: "Tasks", action: nil, keyEquivalent: "")
    private var visible = true

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        buildMenu()
    }

    func setVisible(_ visible: Bool) {
        self.visible = visible
        statusItem.isVisible = visible
    }

    func menuWillOpen(_ menu: NSMenu) {
        if model.runningTaskCount > 0 {
            tasksItem.title = "Tasks · \(model.runningTaskCount) running"
        } else {
            tasksItem.title = "Tasks"
        }
        tasksItem.isEnabled = true
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "NOTCHORA")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = "NOTCHORA — Your AI. One notch away."
        button.setAccessibilityLabel("NOTCHORA")
    }

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        let open = NSMenuItem(title: "Open NOTCHORA", action: #selector(openPanel), keyEquivalent: " ")
        open.keyEquivalentModifierMask = [.option]
        open.target = self
        menu.addItem(open)

        let newChat = NSMenuItem(title: "New Chat", action: #selector(newChat), keyEquivalent: "n")
        newChat.keyEquivalentModifierMask = [.option]
        newChat.target = self
        menu.addItem(newChat)

        menu.addItem(.separator())

        let voice = NSMenuItem(title: "Voice Mode", action: #selector(voiceMode), keyEquivalent: "v")
        voice.keyEquivalentModifierMask = [.option]
        voice.target = self
        menu.addItem(voice)

        let multi = NSMenuItem(title: "Multi-AI", action: #selector(multiAI), keyEquivalent: "m")
        multi.keyEquivalentModifierMask = [.option]
        multi.target = self
        menu.addItem(multi)

        let selection = NSMenuItem(title: "Ask Selected Text", action: #selector(selectedText), keyEquivalent: "s")
        selection.keyEquivalentModifierMask = [.option]
        selection.target = self
        menu.addItem(selection)

        menu.addItem(.separator())

        tasksItem.target = self
        tasksItem.action = #selector(showTasks)
        menu.addItem(tasksItem)

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let about = NSMenuItem(title: "About NOTCHORA", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit NOTCHORA", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func openPanel() {
        model.openPanel()
    }

    @objc private func newChat() {
        _ = model.createConversation(navigate: true)
    }

    @objc private func voiceMode() {
        model.startVoiceMode()
    }

    @objc private func multiAI() {
        model.openMultiAISetup()
    }

    @objc private func selectedText() {
        model.captureSelectedText()
    }

    @objc private func showTasks() {
        model.openPanel(route: .tasks)
    }

    @objc private func showSettings() {
        model.requestSettings(.general)
    }

    @objc private func showAbout() {
        let credits = NSAttributedString(
            string: "Your AI. One notch away.\n\nA native AI control center for macOS.\nBuilt with SwiftUI, AppKit, and Swift Concurrency.",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "NOTCHORA",
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            .version: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
            .credits: credits
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
