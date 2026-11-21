import AppKit
import NotchoraCore
import UniformTypeIdentifiers

enum AppLauncherError: Error, LocalizedError, Sendable {
    case applicationNotFound(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case let .applicationNotFound(name):
            "\(name) is not installed, or macOS cannot locate it."
        case let .launchFailed(message):
            "The application could not be launched: \(message)"
        }
    }
}

@MainActor
final class AppLauncherService {
    func url(for entry: LauncherEntry) -> URL? {
        if let path = entry.applicationPath,
           FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        if let bundleID = entry.bundleIdentifier {
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        }
        return nil
    }

    func runningApplication(for entry: LauncherEntry) -> NSRunningApplication? {
        if let bundleID = entry.bundleIdentifier {
            return NSWorkspace.shared.runningApplications.first {
                $0.bundleIdentifier == bundleID && !$0.isTerminated
            }
        }
        guard let path = entry.applicationPath else { return nil }
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.path == path && !$0.isTerminated
        }
    }

    func isInstalled(_ entry: LauncherEntry) -> Bool {
        url(for: entry) != nil || entry.customURL != nil
    }

    func icon(for entry: LauncherEntry) -> NSImage {
        if let url = url(for: entry) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let customURL = entry.customURL, let url = URL(string: customURL) {
            if let bundle = Bundle(url: url) {
                return NSWorkspace.shared.icon(forFile: bundle.bundlePath)
            }
        }
        return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: entry.name)
            ?? NSImage()
    }

    func open(_ entry: LauncherEntry) async throws {
        if let running = runningApplication(for: entry) {
            running.activate()
            return
        }

        if let customURL = entry.customURL, let url = URL(string: customURL) {
            if !NSWorkspace.shared.open(url) {
                throw AppLauncherError.launchFailed("No application accepted \(url.absoluteString).")
            }
            return
        }

        guard let url = url(for: entry) else {
            throw AppLauncherError.applicationNotFound(entry.name)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        } catch {
            throw AppLauncherError.launchFailed(error.localizedDescription)
        }
    }

    func entry(from url: URL) -> LauncherEntry? {
        guard let bundle = Bundle(url: url) else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return LauncherEntry(
            name: name,
            bundleIdentifier: bundle.bundleIdentifier,
            applicationPath: url.path,
            isSuggested: false
        )
    }
}

@MainActor
final class AppLauncherPicker {
    func chooseApplication() -> LauncherEntry? {
        let panel = NSOpenPanel()
        panel.title = "Add an AI application"
        panel.message = "Choose an application NOTCHORA can open for you."
        panel.prompt = "Add"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return AppLauncherService().entry(from: url)
    }
}
