import NotchoraCore
import SwiftUI

struct ChatView: View {
    let model: AppModel

    @State private var draft = ""

    private var messages: [ChatMessage] { model.currentMessages }
    private var lastMessageID: UUID? { messages.last?.id }
    private var lastContentLength: Int { messages.last?.content.count ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderBar(model: model)

            Group {
                if messages.isEmpty && !model.isBootstrapping {
                    EmptyChatState(model: model) { prompt in
                        draft = prompt
                        model.composerFocusRequest += 1
                    }
                } else {
                    messageList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ComposerView(model: model, draft: $draft)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
        }
        .background(Color.black)
        .onAppear {
            model.composerFocusRequest += 1
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: model.settings.density == .compact ? 12 : 18) {
                    ForEach(messages) { message in
                        ChatMessageRow(
                            message: message,
                            model: model,
                            isLast: message.id == lastMessageID
                        )
                        .id(message.id)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .frame(maxWidth: 820)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                scrollToBottom(proxy, animated: false)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy, animated: true)
            }
            .onChange(of: lastContentLength) { _, _ in
                guard model.isGeneratingCurrent else { return }
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: model.selectedConversationID) { _, _ in
                scrollToBottom(proxy, animated: false)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        guard !messages.isEmpty else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

struct EmptyChatState: View {
    let model: AppModel
    let onPrompt: (String) -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    if !model.hasAnyAPIKey {
                        onboarding
                    } else {
                        greeting
                        suggestions
                        if !recentConversations.isEmpty {
                            recent
                        }
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
        }
    }

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                NotchoraMark(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to NOTCHORA")
                        .font(.nTitle)
                        .foregroundStyle(Color.nTextPrimary)
                    Text("Your AI. One notch away.")
                        .font(.nSmall)
                        .foregroundStyle(Color.nTextSecondary)
                }
                Spacer()
            }

            Text("Connect a provider to start. Requests go directly from this Mac to the provider you choose.")
                .font(.nSmall)
                .foregroundStyle(Color.nTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(1.5)

            VStack(spacing: 4) {
                ForEach(AIProviderID.allCases) { provider in
                    ProviderMiniRow(
                        provider: provider,
                        hasKey: model.hasAPIKey(provider)
                    ) {
                        model.requestSettings(.providers)
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 9, weight: .medium))
                Text("API keys are stored in the macOS Keychain, never in chat history or logs.")
                    .font(.nCaptionRegular)
            }
            .foregroundStyle(Color.nTextTertiary)

            HStack {
                Button("Open AI Provider Settings") {
                    model.requestSettings(.providers)
                }
                .buttonStyle(NButtonStyle(variant: .primary))
                Spacer()
                Text("⌥Space")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.nTextTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            }
        }
        .padding(.vertical, 8)
    }

    private var greeting: some View {
        VStack(spacing: 7) {
            NotchoraMark(size: 42)
            Text(greetingText)
                .font(.nDisplay)
                .foregroundStyle(Color.nTextPrimary)
            Text("Ask anything, compare models, or bring in context from another app.")
                .font(.nSmall)
                .foregroundStyle(Color.nTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    private var suggestions: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                suggestion(
                    icon: "doc.on.clipboard",
                    title: "Use clipboard",
                    detail: "Explain or transform copied text"
                ) {
                    model.attachClipboardText()
                }
                suggestion(
                    icon: "square.split.2x2",
                    title: "Compare models",
                    detail: "One prompt, multiple answers"
                ) {
                    model.openMultiAISetup()
                }
            }
            HStack(spacing: 7) {
                suggestion(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "Review code",
                    detail: "Correctness, risks, clarity"
                ) {
                    onPrompt("Review this code for correctness, security, and maintainability. Explain each finding and suggest a fix.\n\n")
                }
                suggestion(
                    icon: "text.alignleft",
                    title: "Tighten writing",
                    detail: "Clearer, without changing voice"
                ) {
                    onPrompt("Improve the following text. Keep its meaning and voice, and make it clearer and more direct.\n\n")
                }
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: "Recent")
            ForEach(recentConversations) { conversation in
                Button {
                    model.selectConversation(conversation.id)
                } label: {
                    HStack(spacing: 9) {
                        ProviderGlyph(provider: conversation.providerID, size: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(conversation.title)
                                .font(.nSmallMedium)
                                .foregroundStyle(Color.nTextPrimary)
                                .lineLimit(1)
                            if !conversation.preview.isEmpty {
                                Text(conversation.preview)
                                    .font(.nCaptionRegular)
                                    .foregroundStyle(Color.nTextTertiary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(conversation.updatedAt, style: .relative)
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverHighlight(radius: 9)
            }
        }
    }

    private var recentConversations: [Conversation] {
        model.conversationsSorted
            .filter { !$0.messages.isEmpty }
            .prefix(3)
            .map { $0 }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<5: return "Still awake?"
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private func suggestion(
        icon: String,
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.nAccent)
                Text(title)
                    .font(.nSmallMedium)
                    .foregroundStyle(Color.nTextPrimary)
                Text(detail)
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .hoverHighlight(radius: 11)
    }
}
