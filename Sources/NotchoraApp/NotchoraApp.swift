import SwiftUI

@main
struct NotchoraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About NOTCHORA") {
                    AppEnvironment.shared.model.requestSettings(.about)
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    AppEnvironment.shared.model.requestSettings(.general)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
