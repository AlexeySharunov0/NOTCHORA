import Foundation
import NotchoraCore

extension AppModel {
    func handleGlobalShortcut(_ action: ShortcutAction) {
        switch action {
        case .openPanel:
            if presentation == .expanded || presentation == .workspace {
                collapse()
            } else {
                openPanel()
            }
        case .newChat:
            _ = createConversation(navigate: true)
        case .voiceMode:
            startVoiceMode()
        case .selectedText:
            captureSelectedText()
        case .multiAI:
            navigate(.multiAI)
        case .hidePanel:
            hidePanel()
        }
    }

    func openMultiAISetup() {
        navigate(.multiAI)
        if multiAI == nil {
            let selection = activeSelection
            let model = catalog.model(for: selection)
            // The setup screen needs a first choice; it is not a request and
            // does not send anything until the user starts the session.
            multiAI = MultiAISession(
                prompt: "",
                models: [MultiAIModelState(selection: selection, model: model)]
            )
        }
    }
}
