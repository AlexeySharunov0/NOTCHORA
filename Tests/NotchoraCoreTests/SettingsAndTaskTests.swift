import Foundation
import XCTest
@testable import NotchoraCore

@MainActor
final class SettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "notchora.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testDefaultsAndShortcutMappings() {
        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.appearance, .system)
        XCTAssertTrue(settings.animationsEnabled)
        XCTAssertTrue(settings.transparencyEnabled)
        XCTAssertEqual(settings.defaultProviderID, .openAI)
        XCTAssertEqual(settings.shortcuts.count, ShortcutAction.allCases.count)
        XCTAssertTrue(settings.shortcuts.allSatisfy { $0.combo.isSafeGlobalShortcut })
        XCTAssertEqual(settings.binding(for: .openPanel)?.combo, .space)
    }

    func testSettingsPersistAcrossInstances() {
        let settings = SettingsStore(defaults: defaults)
        settings.appearance = .dark
        settings.defaultProviderID = .anthropic
        settings.defaultModelID = "claude-sonnet-4-20250514"
        settings.temperature = 0.25
        settings.voiceAutoSpeak = false
        settings.showMenuBarItem = false
        settings.hasCompletedOnboarding = true

        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.appearance, .dark)
        XCTAssertEqual(restored.defaultProviderID, .anthropic)
        XCTAssertEqual(restored.defaultModelID, "claude-sonnet-4-20250514")
        XCTAssertEqual(restored.temperature, 0.25)
        XCTAssertFalse(restored.voiceAutoSpeak)
        XCTAssertFalse(restored.showMenuBarItem)
        XCTAssertTrue(restored.hasCompletedOnboarding)
    }

    func testShortcutConflictDetectionAndUpdate() {
        let settings = SettingsStore(defaults: defaults)
        let conflicting = KeyCombo(keyCode: 49, modifiers: [.option])
        XCTAssertEqual(settings.duplicateShortcut(for: .newChat, combo: conflicting), .openPanel)

        let newBinding = ShortcutBinding(
            action: .newChat,
            combo: KeyCombo(keyCode: 12, modifiers: [.control, .option]),
            isEnabled: true
        )
        settings.updateShortcut(newBinding)
        XCTAssertEqual(settings.binding(for: .newChat)?.combo, newBinding.combo)
    }

    func testShortcutPersistenceAndReset() {
        let settings = SettingsStore(defaults: defaults)
        let custom = ShortcutBinding(
            action: .voiceMode,
            combo: KeyCombo(keyCode: 14, modifiers: [.control, .shift]),
            isEnabled: false
        )
        settings.updateShortcut(custom)
        XCTAssertEqual(settings.binding(for: .voiceMode)?.combo, custom.combo)
        XCTAssertEqual(settings.binding(for: .voiceMode)?.isEnabled, false)

        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.binding(for: .voiceMode)?.combo, custom.combo)
        XCTAssertEqual(restored.binding(for: .voiceMode)?.isEnabled, false)

        restored.resetShortcuts()
        XCTAssertEqual(restored.binding(for: .voiceMode)?.combo, .optionV)
        XCTAssertEqual(restored.binding(for: .voiceMode)?.isEnabled, true)
    }

    func testUnsafeShortcutRejectedByModel() {
        let combo = KeyCombo(keyCode: 1, modifiers: [])
        XCTAssertFalse(combo.isSafeGlobalShortcut)
        let safe = KeyCombo(keyCode: 1, modifiers: [.option])
        XCTAssertTrue(safe.isSafeGlobalShortcut)
    }

    func testModelSelectionDefaults() {
        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.effectiveModelSelection.providerID, .openAI)
        XCTAssertEqual(settings.effectiveModelSelection.modelID, AIProviderID.openAI.defaultModelID)
        XCTAssertNil(settings.maxOutputTokensValue)
        settings.maxOutputTokens = 500
        XCTAssertEqual(settings.maxOutputTokensValue, 500)
    }
}

@MainActor
final class TaskCenterTests: XCTestCase {
    func testTaskLifecycle() {
        let center = TaskCenter()
        let id = center.create(
            title: "Review",
            kind: .workflow,
            providerID: .anthropic,
            modelID: "claude"
        )
        XCTAssertEqual(center.task(id)?.status, .pending)

        center.markRunning(id)
        XCTAssertEqual(center.task(id)?.status, .running)
        XCTAssertEqual(center.runningCount, 1)

        center.appendResult("Partial", to: id)
        XCTAssertEqual(center.task(id)?.result, "Partial")

        center.complete(id, result: "Done")
        XCTAssertEqual(center.task(id)?.status, .completed)
        XCTAssertEqual(center.task(id)?.result, "Done")
        XCTAssertEqual(center.runningCount, 0)
    }

    func testCancellationAndClearFinished() {
        let center = TaskCenter()
        let cancelled = center.create(title: "A", kind: .chat, providerID: .openAI, modelID: "m")
        center.markRunning(cancelled)
        center.cancel(cancelled)
        XCTAssertEqual(center.task(cancelled)?.status, .cancelled)

        let completed = center.create(title: "B", kind: .chat, providerID: .openAI, modelID: "m")
        center.complete(completed, result: "ok")
        center.clearFinished()
        XCTAssertTrue(center.tasks.isEmpty)
    }

    func testRunningTasksAreRecoveredAsCancelled() {
        let task = AITask(
            title: "Interrupted",
            kind: .chat,
            providerID: .openAI,
            modelID: "m",
            status: .running,
            result: "partial"
        )
        let center = TaskCenter(tasks: [task])
        XCTAssertEqual(center.task(task.id)?.status, .cancelled)
        XCTAssertEqual(center.task(task.id)?.result, "partial")
        XCTAssertNotNil(center.task(task.id)?.errorDescription)
    }

    func testCancelAllCancelsBoundHandlesWithoutMutationCrash() {
        let center = TaskCenter()
        let first = center.create(title: "One", kind: .chat, providerID: .openAI, modelID: "m")
        let second = center.create(title: "Two", kind: .chat, providerID: .openAI, modelID: "m")
        center.markRunning(first)
        center.markRunning(second)

        let handleOne = Task { _ = try? await Task.sleep(for: .seconds(5)) }
        let handleTwo = Task { _ = try? await Task.sleep(for: .seconds(5)) }
        center.bind(handleOne, to: first)
        center.bind(handleTwo, to: second)

        center.cancelAll()
        XCTAssertTrue(handleOne.isCancelled)
        XCTAssertTrue(handleTwo.isCancelled)
        XCTAssertEqual(center.task(first)?.status, .cancelled)
        XCTAssertEqual(center.task(second)?.status, .cancelled)
    }

    func testSortedTasksPutActiveFirst() {
        let center = TaskCenter()
        let first = center.create(title: "Done", kind: .chat, providerID: .openAI, modelID: "m")
        center.complete(first, result: "x")
        let second = center.create(title: "Active", kind: .chat, providerID: .openAI, modelID: "m")
        center.markRunning(second)
        XCTAssertEqual(center.sortedTasks.first?.id, second)
    }
}

@MainActor
final class WorkflowTests: XCTestCase {
    func testWorkflowRunsSequentiallyAndFeedsPreviousOutput() async throws {
        let service = StubAIService(outputs: ["Review output", "Final report"])
        let runner = WorkflowRunner(service: service)
        let workflow = Workflow(
            name: "Test",
            summary: "Test workflow",
            steps: [
                WorkflowStep(
                    name: "Review",
                    providerID: .anthropic,
                    modelID: "claude",
                    promptTemplate: "Review {{input}}",
                    inputSource: .originalRequest
                ),
                WorkflowStep(
                    name: "Synthesize",
                    providerID: .openAI,
                    modelID: "gpt",
                    promptTemplate: "Synthesize {{input}}",
                    inputSource: .previousStep
                )
            ]
        )

        var stepNames: [String] = []
        let results = try await runner.run(workflow: workflow, input: "original") { event in
            if case let .stepStarted(_, name, _, _) = event {
                stepNames.append(name)
            }
        }

        XCTAssertEqual(stepNames, ["Review", "Synthesize"])
        XCTAssertEqual(results.map(\.output), ["Review output", "Final report"])
        XCTAssertEqual(service.requests.count, 2)
        XCTAssertTrue(service.requests[0].messages[0].text.contains("original"))
        XCTAssertTrue(service.requests[1].messages[0].text.contains("Review output"))
        XCTAssertEqual(results[0].providerID, .anthropic)
        XCTAssertEqual(results[1].providerID, .openAI)
    }

    func testAllPreviousStepsIncludesFullReport() async throws {
        let service = StubAIService(outputs: ["one", "two", "three"])
        let runner = WorkflowRunner(service: service)
        let workflow = Workflow(
            name: "Composite",
            summary: "",
            steps: [
                WorkflowStep(name: "One", providerID: .openAI, modelID: "m", promptTemplate: "{{input}}", inputSource: .originalRequest),
                WorkflowStep(name: "Two", providerID: .openAI, modelID: "m", promptTemplate: "{{input}}", inputSource: .previousStep),
                WorkflowStep(name: "Three", providerID: .openAI, modelID: "m", promptTemplate: "Report:\n{{input}}", inputSource: .allPreviousSteps)
            ]
        )
        let results = try await runner.run(workflow: workflow, input: "start") { _ in }
        XCTAssertEqual(results.count, 3)
        let thirdPrompt = service.requests[2].messages[0].text
        XCTAssertTrue(thirdPrompt.contains("## Original request"))
        XCTAssertTrue(thirdPrompt.contains("## Step 1"))
        XCTAssertTrue(thirdPrompt.contains("## Step 2"))
        XCTAssertTrue(thirdPrompt.contains("one"))
        XCTAssertTrue(thirdPrompt.contains("two"))
    }

    func testWorkflowFailureStopsExecution() async {
        let service = StubAIService(failure: .network("offline"))
        let runner = WorkflowRunner(service: service)
        let workflow = Workflow(
            name: "Fail",
            summary: "",
            steps: [
                WorkflowStep(name: "Only", providerID: .openAI, modelID: "m", promptTemplate: "{{input}}", inputSource: .originalRequest)
            ]
        )
        do {
            _ = try await runner.run(workflow: workflow, input: "x") { _ in }
            XCTFail("Expected failure")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .network("offline"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStepInputSelection() {
        let step = WorkflowStep(
            name: "S",
            providerID: .openAI,
            modelID: "m",
            promptTemplate: "Do {{input}}",
            inputSource: .previousStep
        )
        XCTAssertEqual(step.renderedPrompt(input: "work"), "Do work")
        let appended = WorkflowStep(
            name: "S",
            providerID: .openAI,
            modelID: "m",
            promptTemplate: "Do it",
            inputSource: .previousStep
        )
        XCTAssertTrue(appended.renderedPrompt(input: "context").contains("context"))
    }
}

@MainActor
final class ModelCatalogTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "notchora.catalog.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testCustomModelsPersist() throws {
        let catalog = ModelCatalog(defaults: defaults)
        XCTAssertTrue(catalog.models(for: .openAI).count >= 4)
        try catalog.addCustomModel(id: "gpt-custom", provider: .openAI)

        let restored = ModelCatalog(defaults: defaults)
        XCTAssertTrue(restored.models(for: .openAI).contains { $0.id == "gpt-custom" })
        XCTAssertEqual(restored.customModels(for: .openAI).first?.id, "gpt-custom")

        restored.removeCustomModel(id: "gpt-custom", provider: .openAI)
        XCTAssertFalse(restored.models(for: .openAI).contains { $0.id == "gpt-custom" })
    }

    func testDuplicateCustomModelThrows() throws {
        let catalog = ModelCatalog(defaults: defaults)
        try catalog.addCustomModel(id: "custom", provider: .gemini)
        XCTAssertThrowsError(try catalog.addCustomModel(id: "custom", provider: .gemini))
    }

    func testDiscoveredModelsReplaceCuratedListAndPersist() {
        let catalog = ModelCatalog(defaults: defaults)
        let discovered = [
            AIModel(id: "new-model", providerID: .openAI, displayName: "New Model", source: .discovered),
            AIModel(id: "other-model", providerID: .openAI, displayName: "Other", source: .discovered)
        ]
        catalog.installDiscovered(discovered, for: .openAI)
        XCTAssertEqual(catalog.models(for: .openAI).map(\.id).sorted(), ["new-model", "other-model"])

        let restored = ModelCatalog(defaults: defaults)
        XCTAssertEqual(restored.models(for: .openAI).map(\.id).sorted(), ["new-model", "other-model"])
    }

    func testResolveModelFallsBackToCustomSelection() {
        let catalog = ModelCatalog(defaults: defaults)
        let resolved = catalog.model(for: ModelSelection(providerID: .anthropic, modelID: "unknown-model"))
        XCTAssertEqual(resolved.providerID, .anthropic)
        XCTAssertEqual(resolved.id, "unknown-model")
        XCTAssertEqual(resolved.source, .custom)
    }

    func testModelCatalogRefreshUsesService() async throws {
        let model = AIModel(id: "dynamic-model", providerID: .openAI, source: .discovered)
        let provider = MockProvider(id: .openAI, models: [model])
        let service = AIService(
            registry: ProviderRegistry(providers: [provider]),
            keyStore: InMemoryKeychainStore(values: [.openAI: "sk"])
        )
        let catalog = ModelCatalog(defaults: defaults)
        try await catalog.refresh(provider: .openAI, using: service)
        XCTAssertTrue(catalog.models(for: .openAI).contains { $0.id == "dynamic-model" })
        XCTAssertNotNil(catalog.lastRefresh[.openAI])
    }
}
