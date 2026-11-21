import Foundation
import NotchoraCore

extension AppModel {
    func startVoiceMode() {
        voiceSession.configure(
            autoSpeak: settings.voiceAutoSpeak,
            speechRate: settings.speechRate,
            localeIdentifier: settings.voiceLocaleIdentifier
        )
        voicePresented = true
        setPresentation(.expanded)
        if voiceSession.phase == .listening {
            voiceSession.finishAndSend()
        } else if voiceSession.phase == .processing || voiceSession.phase == .responding {
            voiceSession.interrupt()
        } else {
            Task { await voiceSession.startListening() }
        }
    }

    func toggleVoiceListening() {
        guard voicePresented else {
            startVoiceMode()
            return
        }
        switch voiceSession.phase {
        case .listening:
            voiceSession.finishAndSend()
        case .processing, .responding:
            voiceSession.interrupt()
        case .idle, .ready, .error, .interrupted:
            voiceSession.configure(
                autoSpeak: settings.voiceAutoSpeak,
                speechRate: settings.speechRate,
                localeIdentifier: settings.voiceLocaleIdentifier
            )
            Task { await voiceSession.startListening() }
        case .requestingPermission:
            break
        }
    }

    func stopVoiceMode() {
        voiceSession.cancel()
        voicePresented = false
    }

    func sendVoiceMessage(_ text: String) async throws -> String {
        guard let conversationID = selectedConversationID,
              var conversation = conversation(id: conversationID) else {
            throw AIProviderError.network("No conversation is available for Voice Mode.")
        }
        guard !isGenerating(conversationID: conversationID) else {
            throw AIProviderError.stream("Another response is already being generated in this chat.")
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIProviderError.emptyResponse }

        let selection = conversation.selection
        let model = catalog.model(for: selection)
        let userMessage = ChatMessage(role: .user, content: trimmed)
        conversation.applyTitleIfNeeded(fromUserText: trimmed)
        conversation.messages.append(userMessage)

        let placeholder = ChatMessage(
            role: .assistant,
            content: "",
            providerID: selection.providerID,
            modelID: selection.modelID,
            status: .streaming
        )
        conversation.messages.append(placeholder)
        conversation.touch()
        let sourceMessages = conversation.messages.filter { $0.id != placeholder.id }
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            conversations[index] = conversation
        }

        let systemPrompt = conversation.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? settings.defaultSystemPrompt
            : conversation.systemPrompt
        let options = ChatGenerationOptions(
            systemPrompt: systemPrompt,
            temperature: settings.temperature,
            maxOutputTokens: settings.maxOutputTokensValue
        )
        let request: AIRequest
        do {
            request = try ChatRequestBuilder.request(
                messages: sourceMessages,
                model: model,
                options: options
            )
        } catch {
            updateMessage(conversationID: conversationID, messageID: placeholder.id) { message in
                message.status = .failed
                message.errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            scheduleSave()
            throw error
        }
        let taskID = tasks.create(
            title: "Voice · \(String(trimmed.prefix(42)))",
            kind: .voice,
            providerID: selection.providerID,
            modelID: selection.modelID,
            conversationID: conversationID
        )
        tasks.markRunning(taskID)

        let started = ContinuousClock.now
        var fullText = ""
        var usage: TokenUsage?
        var throttle = RenderThrottle()
        do {
            let stream = try await service.stream(request)
            for try await event in stream {
                try Task.checkCancellation()
                switch event {
                case .started:
                    break
                case let .textDelta(delta):
                    fullText += delta
                    if throttle.shouldRender() {
                        updateMessage(conversationID: conversationID, messageID: placeholder.id) {
                            $0.content = fullText
                        }
                    }
                case let .usage(value):
                    usage = value
                    updateMessage(conversationID: conversationID, messageID: placeholder.id) {
                        $0.usage = value
                    }
                case .completed:
                    break
                }
            }
            guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIProviderError.emptyResponse
            }
            let elapsed = ContinuousClock.now - started
            let seconds = Double(elapsed.components.seconds)
                + Double(elapsed.components.attoseconds) / 1e18
            updateMessage(conversationID: conversationID, messageID: placeholder.id) { message in
                message.content = fullText
                message.status = .complete
                message.usage = usage
                message.duration = seconds
            }
            updateConversation(conversationID) { $0.touch() }
            tasks.complete(taskID, result: fullText)
            scheduleSave()
            return fullText
        } catch is CancellationError {
            markCancelled(conversationID: conversationID, messageID: placeholder.id)
            tasks.cancel(taskID)
            scheduleSave()
            throw CancellationError()
        } catch let error as AIProviderError {
            if case .cancelled = error {
                markCancelled(conversationID: conversationID, messageID: placeholder.id)
                tasks.cancel(taskID)
                scheduleSave()
                throw CancellationError()
            }
            updateMessage(conversationID: conversationID, messageID: placeholder.id) { message in
                message.status = .failed
                message.errorDescription = error.errorDescription
            }
            tasks.fail(taskID, error: error.localizedDescription)
            scheduleSave()
            throw error
        } catch {
            let errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            updateMessage(conversationID: conversationID, messageID: placeholder.id) { message in
                message.status = .failed
                message.errorDescription = errorMessage
            }
            tasks.fail(taskID, error: errorMessage)
            scheduleSave()
            throw error
        }
    }
}
