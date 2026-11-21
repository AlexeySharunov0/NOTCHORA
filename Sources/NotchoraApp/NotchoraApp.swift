import SwiftUI

@main
struct NotchoraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRootView(model: AppEnvironment.shared.model)
                .frame(minWidth: 780, minHeight: 560)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    AppEnvironment.shared.model.requestSettings(.general)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
