import XCTest
@testable import NotchoraCore

final class ChatCoreTests: XCTestCase {
    func testChatRequestBuilderMergesAdjacentTurnsAndTextAttachments() throws {
        let attachment = ChatAttachment(
            kind: .text,
            name: "notes.txt",
            mimeType: "text/plain",
            data: Data("attachment body".utf8)
        )
        let messages = [
            ChatMessage(role: .user, content: "First"),
            ChatMessage(role: .user, content: "Second", attachments: [attachment]),
            ChatMessage(role: .assistant, content: "Answer", status: .complete)
        ]
        let request = try ChatRequestBuilder.request(
            messages: messages,
            model: TestFixtures.model(),
            options: ChatGenerationOptions(systemPrompt: "  system  ", temperature: 0.2, maxOutputTokens: 50)
        )

        XCTAssertEqual(request.messages.count, 2)
        XCTAssertEqual(request.messages[0].role, .user)
        XCTAssertTrue(request.messages[0].text.contains("First"))
        XCTAssertTrue(request.messages[0].text.contains("Second"))
        XCTAssertTrue(request.messages[0].text.contains("<attachment name=\"notes.txt\">"))
        XCTAssertTrue(request.messages[0].text.contains("attachment body"))
        XCTAssertEqual(request.messages[1].role, .assistant)
        XCTAssertEqual(request.systemPrompt, "system")
        XCTAssertEqual(request.temperature, 0.2)
        XCTAssertEqual(request.maxOutputTokens, 50)
    }

    func testChatRequestBuilderRejectsImagesForNonVisionModel() {
        let image = ChatAttachment(
            kind: .image,
            name: "shot.png",
            mimeType: "image/png",
            data: Data([1, 2, 3])
        )
        let messages = [ChatMessage(role: .user, content: "Look", attachments: [image])]
        XCTAssertThrowsError(
            try ChatRequestBuilder.request(
                messages: messages,
                model: TestFixtures.model(vision: false),
                options: ChatGenerationOptions()
            )
        ) { error in
            guard case AIProviderError.unsupportedContent = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testChatRequestBuilderPrependsUserWhenTranscriptStartsWithAssistant() throws {
        let request = try ChatRequestBuilder.request(
            messages: [ChatMessage(role: .assistant, content: "Previous answer")],
            model: TestFixtures.model(),
            options: ChatGenerationOptions()
        )
        XCTAssertEqual(request.messages.first?.role, .user)
        XCTAssertEqual(request.messages.first?.text, "Continue the following conversation.")
    }

    func testAIServiceCompletesWithInjectedKey() async throws {
        let provider = MockProvider(id: .openAI, chunks: ["Hello", ", ", "world"])
        let keys = InMemoryKeychainStore(values: [.openAI: "sk-injected"])
        let service = AIService(
            registry: ProviderRegistry(providers: [provider]),
            keyStore: keys
        )
        let result = try await service.complete(TestFixtures.request())

        XCTAssertEqual(result.text, "Hello, world")
        XCTAssertEqual(result.usage, TokenUsage(inputTokens: 1, outputTokens: 2))
        XCTAssertEqual(provider.lastAPIKey, "sk-injected")
    }

    func testAIServiceReportsMissingKey() async {
        let provider = MockProvider(id: .openAI)
        let service = AIService(
            registry: ProviderRegistry(providers: [provider]),
            keyStore: InMemoryKeychainStore()
        )
        do {
            _ = try await service.complete(TestFixtures.request())
            XCTFail("Expected missing key")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .missingAPIKey(.openAI))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAIServiceRejectsEmptyCompletion() async {
        let provider = MockProvider(id: .openAI, chunks: [""], usage: nil)
        let service = AIService(
            registry: ProviderRegistry(providers: [provider]),
            keyStore: InMemoryKeychainStore(values: [.openAI: "sk"])
        )
        do {
            _ = try await service.complete(TestFixtures.request())
            XCTFail("Expected empty response error")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .emptyResponse)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConcurrentIndependentStreams() async throws {
        let provider = MockProvider(id: .openAI, chunks: ["x"])
        let service = AIService(
            registry: ProviderRegistry(providers: [provider]),
            keyStore: InMemoryKeychainStore(values: [.openAI: "sk"])
        )
        async let first = service.complete(TestFixtures.request())
        async let second = service.complete(TestFixtures.request())
        let results = try await [first, second]
        XCTAssertEqual(results.map(\.text), ["x", "x"])
    }

    func testCompareRequestIncludesDisclaimer() throws {
        let answers = [
            CompareAnswer(label: "GPT", providerID: .openAI, modelID: "gpt-4.1", text: "Use a panel."),
            CompareAnswer(label: "Claude", providerID: .anthropic, modelID: "claude", text: "Use a panel carefully.")
        ]
        let request = try CompareRequestBuilder.request(
            originalPrompt: "How should focus work?",
            answers: answers,
            model: TestFixtures.model(.gemini, id: "gemini-2.5-pro"),
            options: ChatGenerationOptions()
        )
        let prompt = request.messages[0].text
        XCTAssertTrue(prompt.contains("Objective") == false)
        XCTAssertTrue(prompt.contains("not an objective fact check"))
        XCTAssertTrue(prompt.contains("GPT"))
        XCTAssertTrue(prompt.contains("Claude"))
        XCTAssertEqual(request.messages.count, 1)
    }

    func testCompareNeedsTwoAnswers() {
        XCTAssertThrowsError(
            try CompareRequestBuilder.request(
                originalPrompt: "Q",
                answers: [CompareAnswer(label: "One", providerID: .openAI, modelID: "m", text: "A")],
                model: TestFixtures.model(),
                options: ChatGenerationOptions()
            )
        )
    }

    func testHandoffDraftPreservesSelectedContextAndSystemInstruction() {
        var conversation = TestFixtures.conversation(provider: .anthropic)
        let selected = Set([conversation.messages[1].id, conversation.messages[2].id])
        let target = ModelSelection(providerID: .openAI, modelID: "gpt-4.1")
        let draft = HandoffBuilder.draft(
            from: conversation,
            scope: .selectedMessages,
            selectedIDs: selected,
            summary: nil,
            target: target
        )

        XCTAssertTrue(draft.contextText.contains("First answer"))
        XCTAssertTrue(draft.contextText.contains("Second question"))
        XCTAssertFalse(draft.contextText.contains("First question"))
        XCTAssertTrue(draft.systemPrompt.contains("untrusted conversational context"))

        let handedOff = HandoffBuilder.makeConversation(from: draft)
        XCTAssertEqual(handedOff.providerID, .openAI)
        XCTAssertEqual(handedOff.modelID, "gpt-4.1")
        XCTAssertEqual(handedOff.messages.count, 1)
        XCTAssertEqual(handedOff.messages[0].role, .user)
        conversation.title = "unchanged"
        XCTAssertNotEqual(handedOff.title, conversation.title)
    }

    func testHandoffSummaryRequestUsesTranscript() {
        let conversation = TestFixtures.conversation()
        let request = HandoffBuilder.summaryRequest(
            conversation: conversation,
            messageIDs: [],
            model: TestFixtures.model(),
            options: ChatGenerationOptions()
        )
        XCTAssertTrue(request.messages[0].text.contains("First question"))
        XCTAssertTrue(request.messages[0].text.contains("<transcript>"))
        XCTAssertTrue(request.systemPrompt?.contains("never invent") == true)
    }

    func testHistoryFilteringAndExcerpts() {
        var first = TestFixtures.conversation(title: "Focus design")
        first.isPinned = true
        var second = TestFixtures.conversation(provider: .gemini, title: "Cooking")
        second.updatedAt = first.updatedAt.addingTimeInterval(-60)
        second.messages[0].content = "A recipe with tomatoes"

        let all = HistorySearch.hits(in: [first, second], filter: HistoryFilter())
        XCTAssertEqual(all.map(\.conversation.title), ["Focus design", "Cooking"])

        let pinned = HistorySearch.hits(in: [first, second], filter: HistoryFilter(pinnedOnly: true))
        XCTAssertEqual(pinned.count, 1)

        let gemini = HistorySearch.hits(in: [first, second], filter: HistoryFilter(providerID: .gemini))
        XCTAssertEqual(gemini.first?.conversation.title, "Cooking")

        let query = HistorySearch.hits(in: [first, second], filter: HistoryFilter(query: "tomatoes"))
        XCTAssertEqual(query.count, 1)
        XCTAssertFalse(query[0].excerpt?.contains("**") ?? true)
    }

    func testPlainTextStripsMarkdownForPreview() {
        let text = "## Title\n\nA **bold** and `code` [link](https://example.com) with a list:\n- one\n- two"
        let preview = PlainText.preview(text, limit: 200)
        XCTAssertFalse(preview.contains("##"))
        XCTAssertFalse(preview.contains("**"))
        XCTAssertFalse(preview.contains("`"))
        XCTAssertFalse(preview.contains("](https://"))
        XCTAssertTrue(preview.contains("Title"))
        XCTAssertTrue(preview.contains("bold"))
        XCTAssertTrue(preview.contains("link"))
    }

    func testConversationPreviewUsesPlainText() {
        var conversation = TestFixtures.conversation()
        conversation.messages.append(ChatMessage(
            role: .assistant,
            content: "**Important** `detail`",
            status: .complete
        ))
        XCTAssertEqual(conversation.preview, "Important detail")
    }
}
