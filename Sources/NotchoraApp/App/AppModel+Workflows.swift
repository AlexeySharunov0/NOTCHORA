import Foundation
import NotchoraCore

extension AppModel {
    func workflowDraft() -> Workflow {
        let provider = settings.defaultProviderID
        return Workflow(
            name: "New Workflow",
            summary: "Describe what this sequence should accomplish.",
            steps: [
                WorkflowStep(
                    name: "Step 1",
                    providerID: provider,
                    modelID: settings.defaultModelID,
                    promptTemplate: "{{input}}",
                    systemPrompt: "",
                    inputSource: .originalRequest
                )
            ]
        )
    }

    func saveWorkflow(_ workflow: Workflow) {
        guard !workflow.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showToast(.warning("Give the workflow a name"))
            return
        }
        guard !workflow.steps.isEmpty else {
            showToast(.warning("Add at least one step"))
            return
        }
        var copy = workflow
        copy.updatedAt = Date()
        if let index = workflows.firstIndex(where: { $0.id == copy.id }) {
            workflows[index] = copy
        } else {
            workflows.insert(copy, at: 0)
        }
        workflowEditor = nil
        scheduleSave()
        showToast(.success("Workflow saved", detail: copy.name))
    }

    func deleteWorkflow(_ id: UUID) {
        workflows.removeAll { $0.id == id }
        if workflowEditor?.id == id { workflowEditor = nil }
        scheduleSave()
    }

    func duplicateWorkflow(_ workflow: Workflow) {
        var copy = workflow
        copy.id = UUID()
        copy.name = "\(workflow.name) copy"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.steps = workflow.steps.map { step in
            var copyStep = step
            copyStep.id = UUID()
            return copyStep
        }
        workflows.insert(copy, at: 0)
        scheduleSave()
    }

    func runWorkflow(_ workflow: Workflow, input rawInput: String) {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            showToast(.warning("Add an input for the workflow"))
            return
        }
        guard !workflows.isEmpty else { return }
        guard workflowRun?.status != .streaming else {
            showToast(.info("A workflow is already running"))
            return
        }

        var display = WorkflowRunDisplay(
            workflowID: workflow.id,
            workflowName: workflow.name,
            input: input,
            currentStep: workflow.steps.first?.name ?? "",
            completedSteps: [],
            status: .streaming
        )
        let taskID = tasks.create(
            title: "Workflow · \(workflow.name)",
            kind: .workflow,
            providerID: workflow.steps.first?.providerID ?? settings.defaultProviderID,
            modelID: workflow.steps.first?.modelID ?? settings.defaultModelID,
            workflowID: workflow.id
        )
        display.taskID = taskID
        workflowRun = display
        route = .workflows
        if presentation == .compact || presentation == .hidden {
            setPresentation(.expanded)
        }

        let runner = WorkflowRunner(service: service)
        let runID = display.id

        let handle = Task { [weak self] in
            guard let self else { return }
            self.tasks.markRunning(taskID)
            do {
                let results = try await runner.run(workflow: workflow, input: input) { [weak self] event in
                    guard let self else { return }
                    self.handleWorkflowEvent(event, runID: runID, taskID: taskID, workflow: workflow)
                }
                _ = results
            } catch is CancellationError {
                self.updateWorkflowRun(runID) {
                    $0.status = .cancelled
                    $0.errorDescription = "Workflow cancelled."
                }
                self.tasks.cancel(taskID)
            } catch let error as AIProviderError {
                if case .cancelled = error {
                    self.updateWorkflowRun(runID) {
                        $0.status = .cancelled
                        $0.errorDescription = "Workflow cancelled."
                    }
                    self.tasks.cancel(taskID)
                } else {
                    let message = error.errorDescription ?? error.localizedDescription
                    self.updateWorkflowRun(runID) {
                        $0.status = .failed
                        $0.errorDescription = message
                    }
                    self.tasks.fail(taskID, error: message)
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.updateWorkflowRun(runID) {
                    $0.status = .failed
                    $0.errorDescription = message
                }
                self.tasks.fail(taskID, error: message)
            }
            self.workflowTask = nil
            self.scheduleSave()
        }
        workflowTask = handle
        tasks.bind(handle, to: taskID)
    }

    func cancelWorkflowRun() {
        guard let display = workflowRun else { return }
        if let taskID = display.taskID { tasks.cancel(taskID) }
        workflowTask?.cancel()
        updateWorkflowRun(display.id) { $0.status = .cancelled }
    }

    private func handleWorkflowEvent(
        _ event: WorkflowRunEvent,
        runID: UUID,
        taskID: UUID,
        workflow: Workflow
    ) {
        switch event {
        case .started:
            break
        case let .stepStarted(index, name, _, _):
            updateWorkflowRun(runID) {
                $0.currentStep = "Step \(index + 1) of \(workflow.steps.count) · \(name)"
            }
            let summary = "Step \(index + 1) of \(workflow.steps.count): \(name)"
            tasks.appendResult(summary, to: taskID)
        case let .stepCompleted(index, result):
            updateWorkflowRun(runID) { display in
                display.completedSteps.append(result)
                display.currentStep = "Step \(index + 1) completed"
            }
            let report = workflowReport(input: workflowRun?.input ?? "", results: workflowRun?.completedSteps ?? [])
            tasks.appendResult(report, to: taskID)
        case let .stepFailed(_, name, message):
            updateWorkflowRun(runID) {
                $0.status = .failed
                $0.errorDescription = "\(name): \(message)"
            }
            tasks.fail(taskID, error: "\(name): \(message)")
        case let .finished(results):
            let finalReport = workflowReport(input: workflowRun?.input ?? "", results: results)
            tasks.complete(taskID, result: finalReport)
            updateWorkflowRun(runID) { $0.status = .completed }
            saveWorkflowConversation(workflow: workflow, input: workflowRun?.input ?? "", results: results)
        }
    }

    private func workflowReport(input: String, results: [WorkflowStepResult]) -> String {
        guard !results.isEmpty else { return "Workflow started." }
        let sections = results.enumerated().map { index, result in
            """
            ## Step \(index + 1) — \(result.stepName)
            \(result.providerID.shortName) · \(result.modelID)

            \(result.output)
            """
        }
        return "Input:\n\(input)\n\n" + sections.joined(separator: "\n\n")
    }

    private func saveWorkflowConversation(
        workflow: Workflow,
        input: String,
        results: [WorkflowStepResult]
    ) {
        guard !results.isEmpty else { return }
        var messages: [ChatMessage] = [ChatMessage(role: .user, content: input)]
        for result in results {
            messages.append(ChatMessage(
                role: .assistant,
                content: "**\(result.stepName)** · \(result.providerID.shortName)\n\n\(result.output)",
                providerID: result.providerID,
                modelID: result.modelID,
                status: .complete,
                usage: result.usage
            ))
        }
        let first = results[0]
        let id = createConversation(
            selection: ModelSelection(providerID: first.providerID, modelID: first.modelID),
            title: "\(workflow.name) · \(String(input.prefix(36)))",
            messages: messages,
            systemPrompt: workflow.steps.first?.systemPrompt ?? "",
            navigate: false
        )
        selectedConversationID = id
        showToast(.success("Workflow completed", detail: "Results saved to History."))
    }

    private func updateWorkflowRun(_ id: UUID, _ mutate: (inout WorkflowRunDisplay) -> Void) {
        guard var display = workflowRun, display.id == id else { return }
        mutate(&display)
        workflowRun = display
    }
}
