import Foundation
import NotchoraCore

extension AppModel {
    func startMultiAI(prompt rawPrompt: String, models: [AIModel]) {
        let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        guard !models.isEmpty else {
            showToast(.warning("Choose at least one model"))
            return
        }

        cancelAllMultiAI()
        let states = models.map { model in
            MultiAIModelState(
                selection: ModelSelection(providerID: model.providerID, modelID: model.id),
                model: model
            )
        }
        var session = MultiAISession(prompt: prompt, models: states)
        session.comparison = nil
        multiAI = session
        projectMultiAIRoute()

        let options = ChatGenerationOptions(
            systemPrompt: settings.defaultSystemPrompt,
            temperature: settings.temperature,
            maxOutputTokens: settings.maxOutputTokensValue
        )

        for state in states {
            let request = AIRequest(
                model: state.model,
                messages: [AIWireMessage(role: .user, text: prompt)],
                systemPrompt: options.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : options.systemPrompt,
                temperature: options.temperature,
                maxOutputTokens: options.maxOutputTokens
            )
            startMultiAITarget(state.id, request: request)
        }
        scheduleSave()
    }

    func retryMultiAITarget(_ targetID: UUID) {
        guard let session = multiAI,
              let index = session.models.firstIndex(where: { $0.id == targetID }) else { return }
        let state = session.models[index]
        if let handle = multiAIHandles[targetID] {
            handle.cancel()
            multiAIHandles[targetID] = nil
        }
        if let taskID = state.taskID { tasks.cancel(taskID) }
        updateMultiAITarget(targetID) {
            $0.status = .waiting
            $0.text = ""
            $0.errorDescription = nil
            $0.usage = nil
        }
        let request = AIRequest(
            model: state.model,
            messages: [AIWireMessage(role: .user, text: session.prompt)],
            systemPrompt: settings.defaultSystemPrompt.nilIfTrimmed,
            temperature: settings.temperature,
            maxOutputTokens: settings.maxOutputTokensValue
        )
        startMultiAITarget(targetID, request: request)
    }

    func cancelMultiAITarget(_ targetID: UUID) {
        multiAIHandles[targetID]?.cancel()
        multiAIHandles[targetID] = nil
        guard let state = multiAI?.models.first(where: { $0.id == targetID }) else { return }
        if let taskID = state.taskID { tasks.cancel(taskID) }
        updateMultiAITarget(targetID) { target in
            target.status = .cancelled
        }
        scheduleSave()
    }

    func cancelAllMultiAI() {
        for handle in multiAIHandles.values { handle.cancel() }
        multiAIHandles.removeAll()
        if let session = multiAI {
            for target in session.models {
                if let taskID = target.taskID { tasks.cancel(taskID) }
            }
        }
        if let comparison = multiAI?.comparison, let taskID = comparison.taskID {
            tasks.cancel(taskID)
        }
        multiAI?.comparison?.status = .idle
    }

    func clearMultiAI() {
        cancelAllMultiAI()
        multiAI = nil
    }

    func startComparison(selection: ModelSelection) {
        guard var session = multiAI else { return }
        let answers = session.completedModels.map { target in
            CompareAnswer(
                label: target.model.displayName,
                providerID: target.selection.providerID,
                modelID: target.selection.modelID,
                text: target.text
            )
        }
        guard answers.count >= 2 else {
            showToast(.warning("Compare Answers needs at least two completed responses"))
            return
        }
        if let existing = session.comparison, existing.status == .streaming {
            return
        }

        let comparisonModel = catalog.model(for: selection)
        let options = ChatGenerationOptions(
            systemPrompt: settings.defaultSystemPrompt,
            temperature: 0.2,
            maxOutputTokens: settings.maxOutputTokensValue
        )
        let request: AIRequest
        do {
            request = try CompareRequestBuilder.request(
                originalPrompt: session.prompt,
                answers: answers,
                model: comparisonModel,
                options: options
            )
        } catch {
            showError(error, title: "Cannot compare answers")
            return
        }

        var comparison = ComparisonState(selection: selection)
        comparison.status = .streaming
        let taskID = tasks.create(
            title: "Compare · \(session.prompt.prefix(42))",
            kind: .compare,
            providerID: selection.providerID,
            modelID: selection.modelID
        )
        comparison.taskID = taskID
        session.comparison = comparison
        multiAI = session

        let comparisonID = comparison.id
        let handle = Task { [weak self] in
            guard let self else { return }
            var text = ""
            var throttle = RenderThrottle()
            do {
                let stream = try await self.service.stream(request)
                for try await event in stream {
                    try Task.checkCancellation()
                    switch event {
                    case .started:
                        self.tasks.markRunning(taskID)
                    case let .textDelta(delta):
                        text += delta
                        if throttle.shouldRender() {
                            self.updateComparison(comparisonID) { $0.text = text }
                        }
                    case .usage, .completed:
                        break
                    }
                }
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AIProviderError.emptyResponse
                }
                self.updateComparison(comparisonID) {
                    $0.text = text
                    $0.status = .completed
                }
                self.tasks.complete(taskID, result: text)
            } catch is CancellationError {
                self.updateComparison(comparisonID) { $0.status = .cancelled }
                self.tasks.cancel(taskID)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.updateComparison(comparisonID) {
                    $0.status = .failed
                    $0.errorDescription = message
                }
                self.tasks.fail(taskID, error: message)
            }
            self.scheduleSave()
        }
        multiAIHandles[comparisonID] = handle
        tasks.bind(handle, to: taskID)
        scheduleSave()
    }

    func cancelComparison() {
        guard let comparison = multiAI?.comparison else { return }
        multiAIHandles[comparison.id]?.cancel()
        multiAIHandles[comparison.id] = nil
        if let taskID = comparison.taskID { tasks.cancel(taskID) }
        updateComparison(comparison.id) { $0.status = .cancelled }
    }

    @discardableResult
    func saveMultiAIResults() -> UUID? {
        guard let session = multiAI else { return nil }
        let completed = session.completedModels
        guard !completed.isEmpty else {
            showToast(.warning("No completed answers to save"))
            return nil
        }

        var messages: [ChatMessage] = [
            ChatMessage(role: .user, content: session.prompt)
        ]
        for target in completed {
            messages.append(ChatMessage(
                role: .assistant,
                content: target.text,
                providerID: target.selection.providerID,
                modelID: target.selection.modelID,
                status: .complete,
                usage: target.usage
            ))
        }
        if let comparison = session.comparison, comparison.status == .completed, !comparison.text.isEmpty {
            messages.append(ChatMessage(
                role: .assistant,
                content: comparison.text,
                providerID: comparison.selection.providerID,
                modelID: comparison.selection.modelID,
                status: .complete
            ))
        }

        let first = completed[0].selection
        let id = createConversation(
            selection: first,
            title: ChatTitle.from("Multi-AI · \(session.prompt)", fallback: "Multi-AI"),
            messages: messages,
            navigate: true
        )
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            conversations[index].systemPrompt = settings.defaultSystemPrompt
        }
        multiAI?.savedConversationID = id
        showToast(.success("Multi-AI session saved to History"))
        scheduleSave()
        return id
    }

    func removeSavedMultiAIReference() {
        multiAI?.savedConversationID = nil
    }

    private func startMultiAITarget(_ targetID: UUID, request: AIRequest) {
        updateMultiAITarget(targetID) {
            $0.status = .waiting
            $0.text = ""
            $0.errorDescription = nil
        }
        guard let model = multiAI?.models.first(where: { $0.id == targetID })?.model else { return }
        let taskID = tasks.create(
            title: "Multi-AI · \(model.displayName)",
            kind: .multiAI,
            providerID: model.providerID,
            modelID: model.id
        )
        updateMultiAITarget(targetID) { $0.taskID = taskID }

        let handle = Task { [weak self] in
            guard let self else { return }
            var text = ""
            var usage: TokenUsage?
            var throttle = RenderThrottle()
            do {
                let stream = try await self.service.stream(request)
                for try await event in stream {
                    try Task.checkCancellation()
                    switch event {
                    case .started:
                        self.tasks.markRunning(taskID)
                        self.updateMultiAITarget(targetID) { $0.status = .streaming }
                    case let .textDelta(delta):
                        text += delta
                        if throttle.shouldRender() {
                            self.updateMultiAITarget(targetID) {
                                $0.status = .streaming
                                $0.text = text
                            }
                        }
                    case let .usage(value):
                        usage = value
                        self.updateMultiAITarget(targetID) { $0.usage = value }
                    case .completed:
                        break
                    }
                }
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AIProviderError.emptyResponse
                }
                self.updateMultiAITarget(targetID) {
                    $0.status = .completed
                    $0.text = text
                    $0.usage = usage
                    $0.errorDescription = nil
                }
                self.tasks.complete(taskID, result: text)
            } catch is CancellationError {
                self.updateMultiAITarget(targetID) { $0.status = .cancelled }
                self.tasks.cancel(taskID)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.updateMultiAITarget(targetID) {
                    $0.status = .failed
                    $0.errorDescription = message
                    $0.text = text
                }
                self.tasks.fail(taskID, error: message)
            }
            self.multiAIHandles[targetID] = nil
            self.scheduleSave()
        }
        multiAIHandles[targetID] = handle
        tasks.bind(handle, to: taskID)
    }

    private func updateMultiAITarget(_ id: UUID, _ mutate: (inout MultiAIModelState) -> Void) {
        guard var session = multiAI,
              let index = session.models.firstIndex(where: { $0.id == id }) else { return }
        mutate(&session.models[index])
        multiAI = session
    }

    private func updateComparison(_ id: UUID, _ mutate: (inout ComparisonState) -> Void) {
        guard var session = multiAI,
              let comparison = session.comparison,
              comparison.id == id else { return }
        var copy = comparison
        mutate(&copy)
        session.comparison = copy
        multiAI = session
    }

    private func projectMultiAIRoute() {
        route = .multiAI
        if presentation == .compact || presentation == .hidden {
            setPresentation(.expanded)
        }
    }
}

private extension String {
    var nilIfTrimmed: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
