import Foundation

public enum WorkflowRunEvent: Sendable {
    case started(runID: UUID)
    case stepStarted(index: Int, name: String, providerID: AIProviderID, modelID: String)
    case stepCompleted(index: Int, result: WorkflowStepResult)
    case stepFailed(index: Int, name: String, message: String)
    case finished(results: [WorkflowStepResult])
}

/// Runs workflow steps sequentially with real model calls. Each step receives
/// exactly one of: the original request, the previous output, or a composed
/// report of all earlier outputs.
@MainActor
public struct WorkflowRunner {
    public let service: any AIServicing

    public init(service: any AIServicing) {
        self.service = service
    }

    public func run(
        workflow: Workflow,
        input: String,
        onEvent: @escaping (WorkflowRunEvent) -> Void
    ) async throws -> [WorkflowStepResult] {
        let runID = UUID()
        onEvent(.started(runID: runID))
        var results: [WorkflowStepResult] = []
        let original = input.trimmingCharacters(in: .whitespacesAndNewlines)

        for (index, step) in workflow.steps.enumerated() {
            try Task.checkCancellation()
            onEvent(.stepStarted(
                index: index,
                name: step.name,
                providerID: step.providerID,
                modelID: step.modelID
            ))

            let stepInput: String
            switch step.inputSource {
            case .originalRequest:
                stepInput = original
            case .previousStep:
                stepInput = results.last?.output ?? original
            case .allPreviousSteps:
                var sections = ["## Original request\n\(original)"]
                for (resultIndex, result) in results.enumerated() {
                    sections.append("## Step \(resultIndex + 1) — \(result.stepName)\n\(result.output)")
                }
                stepInput = sections.joined(separator: "\n\n")
            }

            let model = AIModel(
                id: step.modelID,
                providerID: step.providerID,
                displayName: ModelHeuristics.displayName(for: step.modelID, provider: step.providerID),
                supportsVision: ModelHeuristics.supportsVision(id: step.modelID, provider: step.providerID)
            )
            let request = AIRequest(
                model: model,
                messages: [AIWireMessage(role: .user, text: step.renderedPrompt(input: stepInput))],
                systemPrompt: step.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : step.systemPrompt,
                temperature: nil,
                maxOutputTokens: nil
            )

            do {
                let completion = try await service.complete(request)
                let result = WorkflowStepResult(
                    stepID: step.id,
                    stepName: step.name,
                    providerID: step.providerID,
                    modelID: step.modelID,
                    output: completion.text,
                    usage: completion.usage
                )
                results.append(result)
                onEvent(.stepCompleted(index: index, result: result))
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                onEvent(.stepFailed(index: index, name: step.name, message: message))
                throw error
            }
        }

        onEvent(.finished(results: results))
        return results
    }
}
