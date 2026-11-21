import Foundation

public struct CompareAnswer: Identifiable, Sendable, Hashable {
    public var id: UUID
    public var label: String
    public var providerID: AIProviderID
    public var modelID: String
    public var text: String

    public init(
        id: UUID = UUID(),
        label: String,
        providerID: AIProviderID,
        modelID: String,
        text: String
    ) {
        self.id = id
        self.label = label
        self.providerID = providerID
        self.modelID = modelID
        self.text = text
    }
}

public enum CompareRequestBuilder {
    public static func request(
        originalPrompt: String,
        answers: [CompareAnswer],
        model: AIModel,
        options: ChatGenerationOptions
    ) throws -> AIRequest {
        guard answers.count >= 2 else {
            throw AIProviderError.unsupportedContent("Compare Answers needs at least two completed responses.")
        }

        let renderedAnswers = answers.map { answer -> String in
            let clipped = String(answer.text.prefix(32_000))
            let suffix = answer.text.count > clipped.count ? "\n\n[Response truncated for context size.]" : ""
            return """
            ### \(answer.label)
            Provider: \(answer.providerID.displayName)
            Model: \(answer.modelID)

            \(clipped)\(suffix)
            """
        }.joined(separator: "\n\n")

        let prompt = """
        Compare the following AI responses to the same request.

        Original request:
        \(originalPrompt.isEmpty ? "(not supplied)" : originalPrompt)

        Responses:
        \(renderedAnswers)

        Analyze:
        1. Contradictions between responses.
        2. Likely errors, unsupported claims, or missing evidence.
        3. Strength of argument and usefulness of each response.
        4. What each response does better.
        5. A concise synthesis that preserves genuine disagreement.

        Important: This is a model-generated comparison, not an objective fact check. \
        Do not present a subjective judgment as verified truth. Clearly mark claims that would \
        need external verification.
        """

        let systemPrompt = """
        You are a disciplined comparison analyst. Your job is to surface differences and reasoning quality, \
        not to pretend that model consensus establishes truth. Be specific and fair.
        """

        return AIRequest(
            model: model,
            messages: [AIWireMessage(role: .user, text: prompt)],
            systemPrompt: [options.systemPrompt, systemPrompt]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n\n"),
            temperature: options.temperature,
            maxOutputTokens: options.maxOutputTokens
        )
    }
}
