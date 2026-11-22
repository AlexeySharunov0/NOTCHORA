import AppKit
import Foundation
import NotchoraCore

extension AppModel {
    // MARK: - Providers

    func saveProviderKey(_ key: String, for provider: AIProviderID, verify: Bool) async throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIProviderError.invalidAPIKey(provider)
        }
        providerActionInProgress = provider
        defer { providerActionInProgress = nil }

        if verify {
            try await service.validateKey(trimmed, for: provider)
        }
        try keyStore.save(trimmed, for: provider)
        refreshKeyState()
        providerTestResults[provider] = ProviderTestResult(
            succeeded: true,
            message: verify ? "Key verified and stored in Keychain." : "Key stored in Keychain."
        )
        settings.hasCompletedOnboarding = true

        if verify, let models = try? await service.listModels(for: provider, apiKey: trimmed), !models.isEmpty {
            catalog.installDiscovered(models, for: provider)
            if catalog.models(for: provider).contains(where: { $0.id == settings.defaultModelID }),
               settings.defaultProviderID == provider {
                // Keep the current default.
            } else if settings.defaultProviderID == provider {
                settings.defaultModelID = models[0].id
            }
        }
        scheduleSave()
    }

    func deleteProviderKey(_ provider: AIProviderID) {
        do {
            try keyStore.delete(for: provider)
            refreshKeyState()
            providerTestResults[provider] = nil
            catalog.clearRefreshError(for: provider)
            showToast(.success("\(provider.displayName) key removed from Keychain"))
        } catch {
            showError(error, title: "Could not remove key")
        }
    }

    func deleteAllAPIKeys() {
        for provider in AIProviderID.allCases {
            try? keyStore.delete(for: provider)
        }
        refreshKeyState()
        providerTestResults.removeAll()
        showToast(.success("All API keys removed from Keychain"))
    }

    func testProviderConnection(_ provider: AIProviderID) async {
        guard let key = try? keyStore.load(for: provider), !key.isEmpty else {
            providerTestResults[provider] = ProviderTestResult(
                succeeded: false,
                message: "No API key is stored for \(provider.displayName)."
            )
            return
        }
        providerActionInProgress = provider
        defer { providerActionInProgress = nil }
        do {
            try await service.validateKey(key, for: provider)
            let models = try await service.listModels(for: provider, apiKey: key)
            catalog.installDiscovered(models, for: provider)
            providerTestResults[provider] = ProviderTestResult(
                succeeded: true,
                message: models.isEmpty
                    ? "Connection succeeded. The provider did not list any models."
                    : "Connection succeeded. \(models.count) models available."
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            providerTestResults[provider] = ProviderTestResult(succeeded: false, message: message)
        }
    }

    func refreshProviderModels(_ provider: AIProviderID) async {
        providerActionInProgress = provider
        defer { providerActionInProgress = nil }
        do {
            try await catalog.refresh(provider: provider, using: service)
            providerTestResults[provider] = ProviderTestResult(
                succeeded: true,
                message: "Model list refreshed."
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            providerTestResults[provider] = ProviderTestResult(succeeded: false, message: message)
        }
    }

    func addCustomModel(_ id: String, provider: AIProviderID) {
        do {
            try catalog.addCustomModel(id: id, provider: provider)
            showToast(.success("Model added", detail: id))
        } catch {
            showError(error, title: "Could not add model")
        }
    }

    func removeCustomModel(_ model: AIModel) {
        catalog.removeCustomModel(id: model.id, provider: model.providerID)
        if settings.defaultProviderID == model.providerID && settings.defaultModelID == model.id {
            let fallback = catalog.models(for: model.providerID).first
            settings.defaultModelID = fallback?.id ?? model.providerID.defaultModelID
        }
    }

    func setDefaultSelection(_ selection: ModelSelection) {
        settings.defaultProviderID = selection.providerID
        settings.defaultModelID = selection.modelID
        if let conversation = currentConversation,
           conversation.messages.isEmpty {
            setModelSelection(selection)
        }
    }

    // MARK: - Apps

    func openLauncherEntry(_ entry: LauncherEntry) {
        Task {
            do {
                try await launcherService.open(entry)
            } catch {
                showError(error, title: "Could not open \(entry.name)")
            }
        }
    }

    func addLauncherApplication() {
        guard let entry = launcherPicker.chooseApplication() else { return }
        if launcherEntries.contains(where: {
            ($0.bundleIdentifier != nil && $0.bundleIdentifier == entry.bundleIdentifier)
                || ($0.applicationPath != nil && $0.applicationPath == entry.applicationPath)
        }) {
            showToast(.info("\(entry.name) is already in the list"))
            return
        }
        launcherEntries.append(entry)
        scheduleSave()
        showToast(.success("\(entry.name) added"))
    }

    func removeLauncherEntry(_ entry: LauncherEntry) {
        launcherEntries.removeAll { $0.id == entry.id }
        scheduleSave()
    }

    func resetLauncherSuggestions() {
        launcherEntries = LauncherEntry.suggested
        scheduleSave()
    }

    func launcherIsInstalled(_ entry: LauncherEntry) -> Bool {
        launcherService.isInstalled(entry)
    }

    func launcherIsRunning(_ entry: LauncherEntry) -> Bool {
        launcherService.runningApplication(for: entry) != nil
    }

    // MARK: - Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(enabled)
            settings.launchAtLogin = LaunchAtLoginService.isEnabled
            showToast(.success(enabled ? "NOTCHORA will open at login" : "Launch at login turned off"))
        } catch {
            settings.launchAtLogin = LaunchAtLoginService.isEnabled
            showError(error, title: "Could not change login item")
        }
    }
}
