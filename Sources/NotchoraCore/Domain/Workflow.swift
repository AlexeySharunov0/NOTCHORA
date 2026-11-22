import Foundation

public struct WorkflowStep: Identifiable, Codable, Hashable, Sendable {
    public enum InputSource: String, Codable, Hashable, Sendable, CaseIterable {
        case originalRequest
        case previousStep
        case allPreviousSteps

        public var displayName: String {
            switch self {
            case .originalRequest: "Original request"
            case .previousStep: "Previous step"
            case .allPreviousSteps: "All previous steps"
            }
        }
    }

    public var id: UUID
    public var name: String
    public var providerID: AIProviderID
    public var modelID: String
    public var promptTemplate: String
    public var systemPrompt: String
    public var inputSource: InputSource

    public init(
        id: UUID = UUID(),
        name: String,
        providerID: AIProviderID,
        modelID: String,
        promptTemplate: String,
        systemPrompt: String = "",
        inputSource: InputSource = .previousStep
    ) {
        self.id = id
        self.name = name
        self.providerID = providerID
        self.modelID = modelID
        self.promptTemplate = promptTemplate
        self.systemPrompt = systemPrompt
        self.inputSource = inputSource
    }

    /// Replaces `{{input}}` when present, otherwise appends the selected input
    /// beneath the instruction. This keeps simple templates ergonomic without
    /// hiding what will actually be sent to the model.
    public func renderedPrompt(input: String) -> String {
        if promptTemplate.contains("{{input}}") {
            return promptTemplate.replacingOccurrences(of: "{{input}}", with: input)
        }
        if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return promptTemplate
        }
        return "\(promptTemplate)\n\n---\n\(input)"
    }
}

public struct Workflow: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var summary: String
    public var symbolName: String
    public var steps: [WorkflowStep]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        summary: String,
        symbolName: String = "point.3.connected.trianglepath.dotted",
        steps: [WorkflowStep],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.symbolName = symbolName
        self.steps = steps
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct WorkflowStepResult: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var stepID: UUID
    public var stepName: String
    public var providerID: AIProviderID
    public var modelID: String
    public var output: String
    public var usage: TokenUsage?
    public var errorDescription: String?

    public init(
        id: UUID = UUID(),
        stepID: UUID,
        stepName: String,
        providerID: AIProviderID,
        modelID: String,
        output: String,
        usage: TokenUsage? = nil,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.stepID = stepID
        self.stepName = stepName
        self.providerID = providerID
        self.modelID = modelID
        self.output = output
        self.usage = usage
        self.errorDescription = errorDescription
    }
}

public enum WorkflowPresets {
    public static func standard() -> [Workflow] {
        [
            Workflow(
                name: "Code Review",
                summary: "Claude reviews, GPT challenges the review, then produces a final report.",
                symbolName: "chevron.left.forwardslash.chevron.right",
                steps: [
                    WorkflowStep(
                        name: "Review",
                        providerID: .anthropic,
                        modelID: AIProviderID.anthropic.defaultModelID,
                        promptTemplate: """
                        Review the supplied code as a senior engineer. Identify correctness bugs, security issues, \
                        concurrency hazards, and maintainability risks. Quote the relevant lines and rank findings by severity.

                        {{input}}
                        """,
                        systemPrompt: "You are a rigorous, concise code reviewer. Do not invent code that was not supplied.",
                        inputSource: .originalRequest
                    ),
                    WorkflowStep(
                        name: "Challenge",
                        providerID: .openAI,
                        modelID: AIProviderID.openAI.defaultModelID,
                        promptTemplate: """
                        Audit the code review below. Find incorrect claims, missed issues, and weak reasoning. \
                        Clearly separate confirmed issues from speculation. Do not rewrite the entire review.

                        {{input}}
                        """,
                        systemPrompt: "You are an adversarial reviewer. Be precise and evidence-driven.",
                        inputSource: .previousStep
                    ),
                    WorkflowStep(
                        name: "Final report",
                        providerID: .anthropic,
                        modelID: AIProviderID.anthropic.defaultModelID,
                        promptTemplate: """
                        Produce a final engineering report from the original request, first review, and audit below. \
                        Resolve disagreements explicitly and mark anything that still needs verification.

                        {{input}}
                        """,
                        systemPrompt: "Synthesize faithfully. Never present an unverified claim as fact.",
                        inputSource: .allPreviousSteps
                    )
                ]
            ),
            Workflow(
                name: "Research Brief",
                summary: "Turn a question into a structured brief with counterarguments and open questions.",
                symbolName: "text.magnifyingglass",
                steps: [
                    WorkflowStep(
                        name: "Structure",
                        providerID: .gemini,
                        modelID: AIProviderID.gemini.defaultModelID,
                        promptTemplate: """
                        Build a research brief for the question below. Separate established facts, \
                        assumptions, and open questions. Include the strongest counterargument.

                        {{input}}
                        """,
                        systemPrompt: "You are a careful research editor. Never fabricate sources or citations.",
                        inputSource: .originalRequest
                    )
                ]
            ),
            Workflow(
                name: "Polish Writing",
                summary: "Tighten prose, then have a second model verify meaning and tone.",
                symbolName: "text.quote",
                steps: [
                    WorkflowStep(
                        name: "Edit",
                        providerID: .anthropic,
                        modelID: AIProviderID.anthropic.defaultModelID,
                        promptTemplate: """
                        Edit the text for clarity, rhythm, and precision. Preserve meaning and voice. \
                        Return the edited text only.

                        {{input}}
                        """,
                        systemPrompt: "You are a senior editor with a restrained, natural style.",
                        inputSource: .originalRequest
                    ),
                    WorkflowStep(
                        name: "Meaning check",
                        providerID: .openAI,
                        modelID: AIProviderID.openAI.defaultModelID,
                        promptTemplate: """
                        Compare the edited text with the original request. Flag any change in meaning or tone. \
                        If none, say so briefly.

                        {{input}}
                        """,
                        systemPrompt: "Be skeptical but concise.",
                        inputSource: .allPreviousSteps
                    )
                ]
            )
        ]
    }
}
