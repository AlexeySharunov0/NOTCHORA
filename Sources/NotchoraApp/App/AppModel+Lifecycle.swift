import AppKit
import Foundation
import NotchoraCore

extension AppModel {
    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        Task {
            var loadedState: PersistedState?
            do {
                loadedState = try await stateStore.load()
            } catch {
                showToast(.error(
                    "Local history could not be read",
                    detail: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                ))
            }

            if let state = loadedState {
                conversations = state.conversations.map(Self.sanitizeForLaunch)
                if conversations.isEmpty {
                    let fresh = makeDefaultConversation()
                    conversations = [fresh]
                    selectedConversationID = fresh.id
                } else if let last = state.lastConversationID,
                          conversations.contains(where: { $0.id == last }) {
                    selectedConversationID = last
                } else {
                    selectedConversationID = conversationsSorted.first?.id
                }
                tasks.replace(with: state.tasks)
                workflows = state.workflows
                launcherEntries = state.launcherEntries
            } else {
                let fresh = makeDefaultConversation()
                conversations = [fresh]
                selectedConversationID = fresh.id
                workflows = WorkflowPresets.standard()
                launcherEntries = LauncherEntry.suggested
            }

            if !settings.historyEnabled {
                conversations = [makeDefaultConversation()]
                selectedConversationID = conversations.first?.id
                tasks.reset()
            }

            isBootstrapping = false
            applyAppearance()
            applyMenuBarVisibility()
            reapplyShortcuts()
            enforceHistoryLimit()
            scheduleSave()

            if !settings.hasCompletedOnboarding {
                if !hasAnyAPIKey && !didRequestOnboarding {
                    didRequestOnboarding = true
                    try? await Task.sleep(for: .milliseconds(450))
                    setPresentation(.expanded)
                }
            }
        }
    }

    func scheduleSave() {
        guard didBootstrap else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self?.persistNow()
        }
    }

    func persistNow() async {
        let snapshot = PersistedState(
            conversations: settings.historyEnabled ? conversations : [],
            tasks: tasks.tasks,
            workflows: workflows,
            launcherEntries: launcherEntries,
            lastConversationID: settings.historyEnabled ? selectedConversationID : nil
        )
        do {
            try await stateStore.save(snapshot)
        } catch {
            showToast(.error(
                "Could not save local data",
                detail: error.localizedDescription
            ))
        }
    }

    func flush() async {
        saveTask?.cancel()
        await persistNow()
    }

    func deleteAllLocalData(includingAPIKeys: Bool) {
        generationTasks.values.forEach { $0.cancel() }
        generationTasks.removeAll()
        multiAIHandles.values.forEach { $0.cancel() }
        multiAIHandles.removeAll()
        tasks.reset()
        multiAI = nil
        workflowRun = nil
        selectedTextOffer = nil
        contextDraft = nil

        Task {
            try? await stateStore.deleteAll()
            if includingAPIKeys {
                for provider in AIProviderID.allCases {
                    try? keyStore.delete(for: provider)
                }
                refreshKeyState()
                providerTestResults.removeAll()
            }

            workflows = WorkflowPresets.standard()
            launcherEntries = LauncherEntry.suggested
            let fresh = makeDefaultConversation()
            conversations = [fresh]
            selectedConversationID = fresh.id
            route = .chat
            settings.hasCompletedOnboarding = false
            scheduleSave()
            showToast(.success(
                includingAPIKeys ? "All local data and API keys deleted" : "Local history deleted"
            ))
        }
    }

    func markOnboardingComplete() {
        settings.hasCompletedOnboarding = true
    }

    private func makeDefaultConversation() -> Conversation {
        Conversation(
            providerID: settings.defaultProviderID,
            modelID: settings.defaultModelID
        )
    }

    private static func sanitizeForLaunch(_ conversation: Conversation) -> Conversation {
        var copy = conversation
        copy.messages = copy.messages.compactMap { message in
            var message = message
            if message.status == .streaming {
                message.status = .cancelled
                if message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    message.errorDescription = "Interrupted when NOTCHORA quit."
                }
            }
            if message.role == .assistant,
               message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               message.status != .failed {
                return nil
            }
            return message
        }
        return copy
    }
}
