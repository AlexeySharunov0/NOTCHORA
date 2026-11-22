import AppKit
import Foundation
import NotchoraCore
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    @ObservationIgnored let settings: SettingsStore
    @ObservationIgnored let keyStore: any APIKeyStore
    @ObservationIgnored let registry: ProviderRegistry
    @ObservationIgnored let service: AIService
    @ObservationIgnored let catalog: ModelCatalog
    @ObservationIgnored let stateStore: StateStore
    @ObservationIgnored let tasks: TaskCenter
    @ObservationIgnored let permissions = PermissionCenter()
    @ObservationIgnored let selectedTextService = SelectedTextService()
    @ObservationIgnored let screenCaptureService = ScreenCaptureService()
    @ObservationIgnored let launcherService = AppLauncherService()
    @ObservationIgnored let launcherPicker = AppLauncherPicker()
    @ObservationIgnored let voiceSession: VoiceSession

    var conversations: [Conversation] = []
    var selectedConversationID: UUID?
    var route: AppRoute = .chat
    var presentation: PanelPresentation = .compact
    var isBootstrapping = true
    var toast: ToastMessage?
    var composerFocusRequest = 0
    var selectedTextOffer: SelectedTextOffer?
    var selectionFailure: SelectionFailure?
    var contextDraft: ContextDraft?
    var isCapturingScreen = false
    var multiAI: MultiAISession?
    var workflowRun: WorkflowRunDisplay?
    var workflows: [Workflow] = []
    var launcherEntries: [LauncherEntry] = []
    var workflowEditor: Workflow?
    var keyRevision = 0
    var shortcutRegistrationErrors: [ShortcutAction: String] = [:]
    var historyQuery = ""
    var historyProviderFilter: AIProviderID?
    var historyPinnedOnly = false
    var providerActionInProgress: AIProviderID?
    var providerTestResults: [AIProviderID: ProviderTestResult] = [:]
    var voicePresented = false
    var settingsTabRequest: SettingsTab?
    var isHandoffPresented = false
    var isSystemPromptPresented = false
    var isScreenCapturePickerPresented = false
    var isModelPickerPresented = false
    var presentationAnimationEnabled = true

    @ObservationIgnored var didBootstrap = false
    @ObservationIgnored var generationTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored var multiAIHandles: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored var saveTask: Task<Void, Never>?
    @ObservationIgnored var toastTask: Task<Void, Never>?
    @ObservationIgnored var didRequestOnboarding = false
    @ObservationIgnored var workflowTask: Task<Void, Never>?
    @ObservationIgnored var previousFrontmostPID: pid_t?
    @ObservationIgnored var suppressAutoCollapseForQA = false

    @ObservationIgnored var presentationDidChange: ((PanelPresentation, Bool) -> Void)?
    @ObservationIgnored var menuBarVisibilityChanged: ((Bool) -> Void)?
    @ObservationIgnored var shortcutsChanged: (([ShortcutBinding]) -> Void)?
    @ObservationIgnored var shortcutsRegistrationRequested: (([ShortcutBinding]) -> Void)?
    @ObservationIgnored var appearanceChanged: ((AppAppearance) -> Void)?
    @ObservationIgnored var floatingPanelShouldRebuild: (() -> Void)?

    init(
        settings: SettingsStore,
        keyStore: any APIKeyStore,
        service: AIService,
        stateStore: StateStore,
        catalog: ModelCatalog
    ) {
        self.settings = settings
        self.keyStore = keyStore
        self.service = service
        self.registry = service.registry
        self.catalog = catalog
        self.stateStore = stateStore
        self.tasks = TaskCenter()
        self.workflows = WorkflowPresets.standard()
        self.launcherEntries = LauncherEntry.suggested

        let conversation = Conversation(
            providerID: settings.defaultProviderID,
            modelID: settings.defaultModelID
        )
        self.conversations = [conversation]
        self.selectedConversationID = conversation.id
        self.voiceSession = VoiceSession(permissions: permissions)
        self.voiceSession.onSend = { [weak self] text in
            guard let self else { throw AIProviderError.stream("NOTCHORA is no longer available.") }
            return try await self.sendVoiceMessage(text)
        }
    }

    // MARK: - Derived state

    var currentConversation: Conversation? {
        guard let selectedConversationID else { return nil }
        return conversations.first { $0.id == selectedConversationID }
    }

    var currentMessages: [ChatMessage] {
        currentConversation?.messages ?? []
    }

    var activeSelection: ModelSelection {
        currentConversation?.selection
            ?? ModelSelection(providerID: settings.defaultProviderID, modelID: settings.defaultModelID)
    }

    var activeModel: AIModel {
        catalog.model(for: activeSelection)
    }

    var availableModels: [AIModel] {
        catalog.models(for: activeSelection.providerID)
    }

    var isGeneratingCurrent: Bool {
        currentMessages.contains { $0.role == .assistant && $0.status == .streaming }
    }

    var conversationsSorted: [Conversation] {
        ConversationSort.mostRecent(conversations)
    }

    var hasAnyAPIKey: Bool {
        _ = keyRevision
        return AIProviderID.allCases.contains { keyStore.hasKey(for: $0) }
    }

    var configuredProviders: [AIProviderID] {
        _ = keyRevision
        return AIProviderID.allCases.filter { keyStore.hasKey(for: $0) }
    }

    var runningTaskCount: Int { tasks.runningCount }

    func hasAPIKey(_ provider: AIProviderID) -> Bool {
        _ = keyRevision
        return keyStore.hasKey(for: provider)
    }

    func conversation(id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    func isGenerating(conversationID: UUID) -> Bool {
        conversation(id: conversationID)?.messages.contains(where: {
            $0.role == .assistant && $0.status == .streaming
        }) == true
    }

    // MARK: - Panel

    func setPresentation(_ newValue: PanelPresentation, animated: Bool = true) {
        guard presentation != newValue else {
            if newValue != .hidden { presentationDidChange?(newValue, animated) }
            return
        }
        if newValue == .expanded || newValue == .workspace {
            let frontmost = NSWorkspace.shared.frontmostApplication
            if let frontmost, frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                previousFrontmostPID = frontmost.processIdentifier
            }
            composerFocusRequest += 1
        }
        if newValue == .compact || newValue == .hidden {
            if voicePresented {
                voiceSession.cancel()
                voicePresented = false
            }
            isModelPickerPresented = false
            isHandoffPresented = false
            isSystemPromptPresented = false
            isScreenCapturePickerPresented = false
        }
        presentationAnimationEnabled = animated
        presentation = newValue
        presentationDidChange?(newValue, animated)
        if animated {
            // The window controller owns the actual frame animation.
        }
    }

    func togglePanel() {
        switch presentation {
        case .hidden, .compact:
            setPresentation(route == .settings ? .workspace : .expanded)
        case .expanded, .workspace:
            setPresentation(.compact)
        }
    }

    func openPanel(route newRoute: AppRoute? = nil) {
        if let newRoute {
            route = newRoute
        } else if presentation == .compact || presentation == .hidden,
                  settings.defaultBehavior == .newChat {
            if currentConversation?.messages.isEmpty != true {
                _ = createConversation(navigate: false)
            }
            route = .chat
        }
        setPresentation(route == .settings ? .workspace : .expanded)
    }

    func openWorkspace(route newRoute: AppRoute? = nil) {
        if let newRoute { route = newRoute }
        setPresentation(.workspace)
    }

    func hidePanel() {
        setPresentation(.hidden)
    }

    func collapse() {
        setPresentation(.compact)
    }

    func navigate(_ newRoute: AppRoute, workspace: Bool = false) {
        route = newRoute
        if presentation == .compact || presentation == .hidden {
            setPresentation(workspace ? .workspace : .expanded)
        }
    }

    func requestSettings(_ tab: SettingsTab = .general) {
        settingsTabRequest = tab
        route = .settings
        setPresentation(.workspace)
    }

    func applyAppearance() {
        appearanceChanged?(settings.appearance)
    }

    func applyMenuBarVisibility() {
        menuBarVisibilityChanged?(settings.showMenuBarItem)
    }

    func reapplyShortcuts() {
        shortcutsChanged?(settings.shortcuts)
        shortcutsRegistrationRequested?(settings.shortcuts)
    }

    func updateShortcut(_ binding: ShortcutBinding) {
        if let conflict = settings.duplicateShortcut(for: binding.action, combo: binding.combo) {
            shortcutRegistrationErrors[binding.action] = "Already used by \(conflict.displayName)."
            return
        }
        settings.updateShortcut(binding)
        shortcutRegistrationErrors[binding.action] = nil
        reapplyShortcuts()
    }

    func setShortcutEnabled(_ action: ShortcutAction, enabled: Bool) {
        guard var binding = settings.binding(for: action) else { return }
        binding.isEnabled = enabled
        settings.updateShortcut(binding)
        reapplyShortcuts()
    }

    func resetShortcuts() {
        settings.resetShortcuts()
        shortcutRegistrationErrors = [:]
        reapplyShortcuts()
    }

    // MARK: - Conversations

    @discardableResult
    func createConversation(
        selection: ModelSelection? = nil,
        title: String = "New Chat",
        messages: [ChatMessage] = [],
        systemPrompt: String = "",
        navigate: Bool = true
    ) -> UUID {
        let chosen = selection ?? ModelSelection(
            providerID: settings.defaultProviderID,
            modelID: settings.defaultModelID
        )
        var conversation = Conversation(
            title: title,
            providerID: chosen.providerID,
            modelID: chosen.modelID,
            systemPrompt: systemPrompt,
            messages: messages
        )
        conversation.touch()
        conversations.insert(conversation, at: 0)
        selectedConversationID = conversation.id
        if navigate {
            route = .chat
            setPresentation(.expanded)
        }
        enforceHistoryLimit()
        scheduleSave()
        return conversation.id
    }

    func selectConversation(_ id: UUID, navigate: Bool = true) {
        guard conversations.contains(where: { $0.id == id }) else { return }
        selectedConversationID = id
        if navigate {
            route = .chat
            if presentation == .compact || presentation == .hidden {
                setPresentation(.expanded)
            }
        }
        scheduleSave()
    }

    func updateConversation(_ id: UUID, _ mutate: (inout Conversation) -> Void) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        mutate(&conversations[index])
        scheduleSave()
    }

    func updateCurrentConversation(_ mutate: (inout Conversation) -> Void) {
        guard let id = selectedConversationID else { return }
        updateConversation(id, mutate)
    }

    func setModelSelection(_ selection: ModelSelection, for conversationID: UUID? = nil) {
        let id = conversationID ?? selectedConversationID
        guard let id else { return }
        updateConversation(id) { conversation in
            conversation.selection = selection
            conversation.touch()
        }
        settings.defaultProviderID = selection.providerID
        settings.defaultModelID = selection.modelID
    }

    func renameConversation(_ id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updateConversation(id) {
            $0.title = String(trimmed.prefix(80))
            $0.touch()
        }
    }

    func togglePin(_ id: UUID) {
        updateConversation(id) {
            $0.isPinned.toggle()
            $0.touch()
        }
    }

    func deleteConversation(_ id: UUID) {
        generationTasks[id]?.cancel()
        generationTasks[id] = nil
        conversations.removeAll { $0.id == id }
        if selectedConversationID == id {
            selectedConversationID = conversationsSorted.first?.id
            if selectedConversationID == nil {
                _ = createConversation(navigate: false)
            }
        }
        scheduleSave()
    }

    func deleteCurrentConversation() {
        guard let id = selectedConversationID else { return }
        deleteConversation(id)
    }

    func clearAllConversations() {
        generationTasks.values.forEach { $0.cancel() }
        generationTasks.removeAll()
        conversations.removeAll()
        selectedConversationID = nil
        _ = createConversation(navigate: false)
        route = .chat
        scheduleSave()
    }

    func enforceHistoryLimit() {
        guard settings.historyEnabled, settings.maxStoredConversations > 0 else { return }
        guard conversations.count > settings.maxStoredConversations else { return }
        let protected = Set([selectedConversationID].compactMap { $0 })
        var removable = conversations
            .filter { !$0.isPinned && !protected.contains($0.id) }
            .sorted { $0.updatedAt < $1.updatedAt }
        while conversations.count > settings.maxStoredConversations, let victim = removable.first {
            conversations.removeAll { $0.id == victim.id }
            removable.removeFirst()
        }
    }

    // MARK: - Toasts

    func showToast(_ toast: ToastMessage) {
        toastTask?.cancel()
        withAnimation(.snappy(duration: 0.28)) {
            self.toast = toast
        }
        let delay: Duration = toast.kind == .error ? .seconds(7) : .seconds(4)
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.toast?.id == toast.id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    self?.toast = nil
                }
            }
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) {
            toast = nil
        }
    }

    func showError(_ error: any Error, title: String? = nil) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        showToast(.error(title ?? "Something went wrong", detail: message))
    }

    // MARK: - Context

    func clearContextDraft() {
        contextDraft = nil
    }

    func presentSelectedText(_ offer: SelectedTextOffer) {
        selectedTextOffer = offer
        setPresentation(.expanded)
    }

    // MARK: - API key state

    func refreshKeyState() {
        keyRevision += 1
    }

    func hasStoredKey(_ provider: AIProviderID) -> Bool {
        _ = keyRevision
        return keyStore.hasKey(for: provider)
    }
}

struct ProviderTestResult: Sendable, Equatable {
    var succeeded: Bool
    var message: String
    var date = Date()
}
