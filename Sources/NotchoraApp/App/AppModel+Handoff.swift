import Foundation
import NotchoraCore

extension AppModel {
    func makeHandoffDraft(
        scope: HandoffScope,
        selectedIDs: Set<UUID>,
        target: ModelSelection,
        summary: String?
    ) -> HandoffDraft? {
        guard let conversation = currentConversation else { return nil }
        return HandoffBuilder.draft(
            from: conversation,
            scope: scope,
            selectedIDs: selectedIDs,
            summary: summary,
            target: target
        )
    }

    func summarizeForHandoff(
        conversationID: UUID,
        selectedIDs: Set<UUID>,
        summarizer: ModelSelection
    ) async throws -> String {
        guard let conversation = conversation(id: conversationID) else {
            throw AIProviderError.network("The source conversation is no longer available.")
        }
        let model = catalog.model(for: summarizer)
        let options = ChatGenerationOptions(
            systemPrompt: "",
            temperature: 0.2,
            maxOutputTokens: 1600
        )
        let request = HandoffBuilder.summaryRequest(
            conversation: conversation,
            messageIDs: selectedIDs,
            model: model,
            options: options
        )
        let result = try await service.complete(request)
        return result.text
    }

    @discardableResult
    func performHandoff(_ draft: HandoffDraft, autoContinue: Bool = true) -> UUID {
        let conversation = HandoffBuilder.makeConversation(from: draft)
        conversations.insert(conversation, at: 0)
        selectedConversationID = conversation.id
        route = .chat
        setPresentation(.expanded)
        scheduleSave()
        showToast(.success(
            "Handoff complete",
            detail: "Continue in \(draft.target.providerID.shortName)."
        ))
        if autoContinue {
            generateResponse(in: conversation.id)
        }
        return conversation.id
    }
}
