#if DEBUG
import AppKit
import NotchoraCore
import SwiftUI

/// Debug-only visual QA harness. It never runs in a release build and is
/// enabled explicitly with NOTCHORA_QA=1. Fixtures are used only to render
/// screenshots; no network request is made.
@MainActor
enum QAHarness {
    static func runIfNeeded(model: AppModel, panel: NSWindow?) {
        guard ProcessInfo.processInfo.environment["NOTCHORA_QA"] == "1" else { return }
        Task {
            await run(model: model, panel: panel)
        }
    }

    private static func run(model: AppModel, panel: NSWindow?) async {
        let outputDirectory = URL(fileURLWithPath:
            ProcessInfo.processInfo.environment["NOTCHORA_QA_DIR"]
            ?? "\(FileManager.default.currentDirectoryPath)/build/screenshots/qa"
        )
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        try? await Task.sleep(for: .seconds(1.6))
        model.suppressAutoCollapseForQA = true
        for provider in AIProviderID.allCases {
            try? model.keyStore.delete(for: provider)
        }
        model.refreshKeyState()
        model.settings.hasCompletedOnboarding = true
        model.setPresentation(.compact, animated: false)
        try? await Task.sleep(for: .milliseconds(500))
        capture(panel, name: "01-compact", directory: outputDirectory)

        model.setPresentation(.expanded, animated: false)
        try? await Task.sleep(for: .milliseconds(700))
        capture(panel, name: "02-onboarding", directory: outputDirectory)
        let focus = panel?.firstResponder.map { String(describing: type(of: $0)) } ?? "nil"
        let shortcutReport = model.shortcutRegistrationErrors
            .map { "\($0.key.rawValue)=\($0.value)" }
            .sorted()
            .joined(separator: "\n")
        let runtimeReport = """
        firstResponder: \(focus)
        shortcutErrors: \(shortcutReport.isEmpty ? "none" : shortcutReport)
        presentation: \(model.presentation.rawValue)
        """
        try? runtimeReport.write(
            to: outputDirectory.appendingPathComponent("runtime-status.txt"),
            atomically: true,
            encoding: .utf8
        )

        for provider in AIProviderID.allCases {
            try? model.keyStore.save("qa-placeholder", for: provider)
        }
        model.refreshKeyState()

        let conversation = fixtureConversation()
        model.conversations = [conversation]
        model.selectedConversationID = conversation.id
        model.route = .chat
        model.settings.appearance = .dark
        model.applyAppearance()
        model.setPresentation(.expanded, animated: false)
        try? await Task.sleep(for: .milliseconds(700))
        capture(panel, name: "03-chat-dark", directory: outputDirectory)

        model.settings.appearance = .light
        model.applyAppearance()
        model.setPresentation(.expanded, animated: false)
        try? await Task.sleep(for: .milliseconds(650))
        capture(panel, name: "04-chat-light", directory: outputDirectory)

        model.settings.appearance = .dark
        model.applyAppearance()
        model.setPresentation(.workspace, animated: false)
        try? await Task.sleep(for: .milliseconds(700))
        capture(panel, name: "05-workspace-dark", directory: outputDirectory)

        model.settings.appearance = .light
        model.applyAppearance()
        model.setPresentation(.workspace, animated: false)
        try? await Task.sleep(for: .milliseconds(550))
        capture(panel, name: "06-workspace-light", directory: outputDirectory)

        model.settings.appearance = .dark
        model.applyAppearance()
        model.setPresentation(.workspace, animated: false)
        model.route = .history
        model.historyQuery = ""
        try? await Task.sleep(for: .milliseconds(500))
        capture(panel, name: "07-history", directory: outputDirectory)

        installTaskFixtures(in: model)
        model.route = .tasks
        try? await Task.sleep(for: .milliseconds(500))
        capture(panel, name: "08-tasks", directory: outputDirectory)

        model.route = .workflows
        try? await Task.sleep(for: .milliseconds(400))
        capture(panel, name: "09-workflows", directory: outputDirectory)

        model.multiAI = fixtureMultiAI()
        model.route = .multiAI
        try? await Task.sleep(for: .milliseconds(500))
        capture(panel, name: "10-multi-ai", directory: outputDirectory)

        await captureSettings(model: model, panel: panel, directory: outputDirectory)

        model.route = .chat
        model.setPresentation(.compact, animated: false)
        try? await Task.sleep(for: .milliseconds(400))
        capture(panel, name: "11-compact-active", directory: outputDirectory)

        // Capture the same window while it is physically growing, to make the
        // continuous notch expansion reviewable frame by frame.
        model.setPresentation(.expanded, animated: true)
        try? await Task.sleep(for: .milliseconds(70))
        capture(panel, name: "16-expand-70ms", directory: outputDirectory)
        try? await Task.sleep(for: .milliseconds(100))
        capture(panel, name: "17-expand-170ms", directory: outputDirectory)
        try? await Task.sleep(for: .milliseconds(180))
        capture(panel, name: "18-expand-350ms", directory: outputDirectory)
        try? await Task.sleep(for: .milliseconds(400))
        capture(panel, name: "19-expand-final", directory: outputDirectory)

        model.isModelPickerPresented = true
        try? await Task.sleep(for: .milliseconds(350))
        capture(panel, name: "24-model-picker", directory: outputDirectory)
        model.isModelPickerPresented = false

        model.isHandoffPresented = true
        try? await Task.sleep(for: .milliseconds(400))
        capture(panel, name: "25-handoff", directory: outputDirectory)
        model.isHandoffPresented = false

        model.isSystemPromptPresented = true
        try? await Task.sleep(for: .milliseconds(300))
        capture(panel, name: "26-system-prompt", directory: outputDirectory)
        model.isSystemPromptPresented = false

        model.isScreenCapturePickerPresented = true
        try? await Task.sleep(for: .milliseconds(300))
        capture(panel, name: "27-screen-capture", directory: outputDirectory)
        model.isScreenCapturePickerPresented = false

        model.isModelPickerPresented = false
        model.voicePresented = true
        try? await Task.sleep(for: .milliseconds(300))
        capture(panel, name: "28-voice", directory: outputDirectory)
        model.voicePresented = false

        model.setPresentation(.workspace, animated: false)
        model.route = .workflows
        try? await Task.sleep(for: .milliseconds(400))
        model.workflowEditor = model.workflowDraft()
        try? await Task.sleep(for: .milliseconds(400))
        capture(panel, name: "29-workflow-editor", directory: outputDirectory)
        model.workflowEditor = nil
        model.route = .chat
        model.setPresentation(.expanded, animated: false)
        try? await Task.sleep(for: .milliseconds(300))

        // Collapse the same surface back into the notch and sample the shrink.
        model.setPresentation(.compact, animated: true)
        try? await Task.sleep(for: .milliseconds(80))
        capture(panel, name: "20-collapse-80ms", directory: outputDirectory)
        try? await Task.sleep(for: .milliseconds(120))
        capture(panel, name: "21-collapse-200ms", directory: outputDirectory)
        try? await Task.sleep(for: .milliseconds(200))
        capture(panel, name: "22-collapse-400ms", directory: outputDirectory)
        try? await Task.sleep(for: .milliseconds(700))
        capture(panel, name: "23-collapse-final", directory: outputDirectory)

        print("QA screenshots written to \(outputDirectory.path)")
        fflush(stdout)
        exit(0)
    }

    private static func capture(_ window: NSWindow?, name: String, directory: URL) {
        guard let view = window?.contentView else {
            print("QA capture: no window for \(name)")
            return
        }
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0,
              let representation = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            print("QA capture: no bitmap for \(name)")
            return
        }
        view.cacheDisplay(in: bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            print("QA capture: no PNG for \(name)")
            return
        }
        let url = directory.appendingPathComponent("\(name).png")
        do {
            try data.write(to: url)
            print("QA capture: \(url.lastPathComponent) \(Int(bounds.width))×\(Int(bounds.height)) window=\(window?.frame ?? .zero)")
        } catch {
            print("QA capture failed: \(error)")
        }
    }

    private static func captureSettings(model: AppModel, panel: NSWindow?, directory: URL) async {
        model.requestSettings(.general)
        try? await Task.sleep(for: .milliseconds(900))
        capture(panel, name: "12-settings-general", directory: directory)

        model.settingsTabRequest = .providers
        try? await Task.sleep(for: .milliseconds(500))
        capture(panel, name: "13-settings-providers", directory: directory)

        model.settingsTabRequest = .privacy
        try? await Task.sleep(for: .milliseconds(500))
        capture(panel, name: "14-settings-privacy", directory: directory)

        model.settings.appearance = .light
        model.applyAppearance()
        try? await Task.sleep(for: .milliseconds(600))
        capture(panel, name: "15-settings-light", directory: directory)
    }

    private static func fixtureConversation() -> Conversation {
        let model = ModelSelection(providerID: .anthropic, modelID: "claude-sonnet-4-20250514")
        var conversation = Conversation(
            title: "Notch panel architecture",
            providerID: model.providerID,
            modelID: model.modelID,
            systemPrompt: "Be precise about native macOS behavior."
        )
        conversation.messages = [
            ChatMessage(
                role: .user,
                content: "I'm building a menu bar AI panel for macOS. Should it activate the app when the notch expands, and how should it behave across Spaces?",
                createdAt: Date().addingTimeInterval(-320)
            ),
            ChatMessage(
                role: .assistant,
                content: """
                ## Recommendation

                Activate the app **only while the panel is open**, then return focus to the previous app when it collapses. A borderless `NSPanel` can become key without taking over the menu bar, but text input and VoiceOver are more reliable when the app is active.

                ### Panel behavior

                1. Use a nonactivating panel style for the collapsed notch.
                2. On expansion, save the frontmost app and call `NSApp.activate`.
                3. On collapse, restore the saved app only if NOTCHORA is still frontmost.
                4. Join all Spaces and allow full-screen auxiliary presentation.

                ```swift
                final class NotchPanel: NSPanel {
                    override var canBecomeKey: Bool { true }
                    override var canBecomeMain: Bool { false }
                }

                panel.collectionBehavior = [
                    .canJoinAllSpaces,
                    .fullScreenAuxiliary,
                    .stationary
                ]
                ```

                | Concern | Approach |
                | --- | --- |
                | Focus | Restore the previous app on collapse |
                | Spaces | `canJoinAllSpaces` + `stationary` |
                | Full screen | `fullScreenAuxiliary` |
                | Multiple displays | Anchor to the active `NSScreen` |

                Keep the collapsed state visually quiet. A small activity dot is enough; do not animate the panel when nothing is happening.
                """,
                createdAt: Date().addingTimeInterval(-300),
                providerID: .anthropic,
                modelID: "claude-sonnet-4-20250514",
                status: .complete,
                usage: TokenUsage(inputTokens: 1820, outputTokens: 412),
                duration: 3.8
            ),
            ChatMessage(
                role: .user,
                content: "What about the compact state when there is no physical notch?",
                createdAt: Date().addingTimeInterval(-60)
            ),
            ChatMessage(
                role: .assistant,
                content: """
                Fall back to a **small floating pill** just below the menu bar. Keep the same interaction model and visual language, but do not fake a camera cutout.

                - Anchor below `visibleFrame.maxY`
                - Leave a 6 pt gap from the menu bar
                - Keep the same keyboard shortcut
                - Never assume `safeAreaInsets.top > 0`

                The panel should still feel attached to the top edge, even without hardware to merge with.
                """,
                createdAt: Date().addingTimeInterval(-40),
                providerID: .anthropic,
                modelID: "claude-sonnet-4-20250514",
                status: .complete,
                usage: TokenUsage(inputTokens: 2300, outputTokens: 140),
                duration: 1.9
            )
        ]
        return conversation
    }

    private static func installTaskFixtures(in model: AppModel) {
        model.tasks.reset()
        let running = model.tasks.create(
            title: "Code review · NotchPanel.swift",
            kind: .workflow,
            providerID: .anthropic,
            modelID: "claude-sonnet-4-20250514"
        )
        model.tasks.markRunning(running)

        let completed = model.tasks.create(
            title: "Compare focus handling",
            kind: .compare,
            providerID: .gemini,
            modelID: "gemini-2.5-pro"
        )
        model.tasks.markRunning(completed)
        model.tasks.complete(completed, result: "Claude emphasizes reliability of activation; GPT highlights avoiding focus theft. Both agree that restoring the previous app matters.")

        let failed = model.tasks.create(
            title: "Summarize accessibility notes",
            kind: .chat,
            providerID: .openAI,
            modelID: "gpt-4.1"
        )
        model.tasks.markRunning(failed)
        model.tasks.fail(failed, error: "The request timed out after 30 seconds. Check your connection.")
    }

    private static func fixtureMultiAI() -> MultiAISession {
        let openAI = AIModel(id: "gpt-4.1", providerID: .openAI, displayName: "GPT-4.1", supportsVision: true)
        let claude = AIModel(id: "claude-sonnet-4-20250514", providerID: .anthropic, displayName: "Claude Sonnet 4", supportsVision: true)
        let gemini = AIModel(id: "gemini-2.5-pro", providerID: .gemini, displayName: "Gemini 2.5 Pro", supportsVision: true)

        var session = MultiAISession(
            prompt: "How should a native macOS AI panel handle focus when it expands over another app?",
            models: [
                MultiAIModelState(
                    selection: ModelSelection(providerID: .openAI, modelID: openAI.id),
                    model: openAI,
                    text: """
                    Use a **nonactivating panel** for the collapsed state and activate only when the user opens the input surface. Save the previously frontmost application and restore it on collapse.

                    The key tradeoff is reliability versus focus theft. If the panel never activates, text fields, accessibility, and VoiceOver can behave inconsistently.
                    """,
                    status: .completed,
                    usage: TokenUsage(inputTokens: 42, outputTokens: 68)
                ),
                MultiAIModelState(
                    selection: ModelSelection(providerID: .anthropic, modelID: claude.id),
                    model: claude,
                    text: """
                    A notch panel should feel like a temporary surface, not an app switch.

                    1. Preserve the previous app.
                    2. Activate only when the panel needs keyboard input.
                    3. Return focus immediately on collapse.
                    4. Keep the compact state nonactivating.

                    The risk is a panel that looks open but cannot accept typing.
                    """,
                    status: .completed,
                    usage: TokenUsage(inputTokens: 42, outputTokens: 72)
                ),
                MultiAIModelState(
                    selection: ModelSelection(providerID: .gemini, modelID: gemini.id),
                    model: gemini,
                    text: "A nonactivating NSPanel can become key, but macOS focus behavior varies by app and full-screen space. Test with VoiceOver and multiple displays.",
                    status: .completed,
                    usage: TokenUsage(inputTokens: 42, outputTokens: 33)
                )
            ]
        )
        session.comparison = ComparisonState(
            selection: ModelSelection(providerID: .openAI, modelID: "gpt-4.1"),
            text: """
            **Agreement:** all three responses favor restoring focus and activating only while the user is interacting.

            **Tension:** GPT and Claude disagree on whether a nonactivating panel is sufficient for reliable keyboard input. Given macOS behavior, activation during interaction is the safer implementation.

            **Still needs verification:** VoiceOver behavior across full-screen Spaces.

            *This is a model-generated comparison, not an objective fact check.*
            """,
            status: .completed
        )
        return session
    }
}
#endif
