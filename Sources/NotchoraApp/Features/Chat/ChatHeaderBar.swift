import NotchoraCore
import SwiftUI

struct ChatHeaderBar: View {
    let model: AppModel

    @Environment(\.colorScheme) private var colorScheme
    @State private var renamePresented = false
    @State private var renameText = ""

    var body: some View {
        HStack(spacing: 8) {
            ConversationSwitcher(model: model)
                .frame(maxWidth: 210, alignment: .leading)

            Spacer(minLength: 4)

            if model.isGeneratingCurrent {
                Spinner()
                    .padding(.trailing, 1)
            }

            ModelPickerButton(model: model)

            Button {
                guard !model.currentMessages.isEmpty else {
                    model.showToast(.info("Start a conversation before handing it off"))
                    return
                }
                model.isHandoffPresented = true
            } label: {
                Label("Handoff", systemImage: "arrow.left.arrow.right")
                    .labelStyle(.iconOnly)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(model.currentMessages.isEmpty ? handoffColor.opacity(0.45) : handoffColor)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Handoff to another model")
            .accessibilityLabel("Handoff to another model")

            Menu {
                Button {
                    model.createConversation(navigate: true)
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
                Button {
                    model.isHandoffPresented = true
                } label: {
                    Label("Handoff…", systemImage: "arrow.left.arrow.right")
                }
                Divider()
                Button {
                    renameText = model.currentConversation?.title ?? ""
                    renamePresented = true
                } label: {
                    Label("Rename Chat…", systemImage: "pencil")
                }
                Button {
                    model.isSystemPromptPresented = true
                } label: {
                    Label("System Prompt…", systemImage: "text.badge.star")
                }
                Button {
                    model.togglePinnedCurrent()
                } label: {
                    Label(
                        model.currentConversation?.isPinned == true ? "Unpin Chat" : "Pin Chat",
                        systemImage: model.currentConversation?.isPinned == true ? "pin.slash" : "pin"
                    )
                }
                Divider()
                Button {
                    if let conversation = model.currentConversation {
                        let transcript = conversation.messages.map {
                            "\($0.role == .user ? "You" : "Assistant"):\n\($0.content)"
                        }.joined(separator: "\n\n")
                        model.copyToClipboard(transcript)
                    }
                } label: {
                    Label("Copy Transcript", systemImage: "doc.on.doc")
                }
                .disabled(model.currentMessages.isEmpty)
                Button(role: .destructive) {
                    model.clearCurrentMessages()
                } label: {
                    Label("Clear Messages", systemImage: "eraser")
                }
                .disabled(model.currentMessages.isEmpty)
                Button(role: .destructive) {
                    model.deleteCurrentConversation()
                } label: {
                    Label("Delete Chat", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.nTextSecondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Chat options")
            .accessibilityLabel("Chat options")
        }
        .padding(.horizontal, 13)
        .frame(height: 46)
        .alert("Rename Chat", isPresented: $renamePresented) {
            TextField("Chat title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let id = model.selectedConversationID {
                    model.renameConversation(id, to: renameText)
                }
            }
        } message: {
            Text("Choose a short, recognizable title.")
        }
    }
    private var handoffColor: Color {
        Color.white.opacity(0.62)
    }
}

struct ConversationSwitcher: View {
    let model: AppModel

    var body: some View {
        Menu {
            Button {
                model.createConversation(navigate: true)
            } label: {
                Label("New Chat", systemImage: "plus")
            }
            Divider()
            ForEach(model.conversationsSorted.prefix(10)) { conversation in
                Button {
                    model.selectConversation(conversation.id)
                } label: {
                    if conversation.id == model.selectedConversationID {
                        Label(conversation.title, systemImage: "checkmark")
                    } else {
                        Text(conversation.title)
                    }
                }
            }
            Divider()
            Button {
                model.navigate(.history)
            } label: {
                Label("Browse History", systemImage: "clock.arrow.circlepath")
            }
        } label: {
            HStack(spacing: 5) {
                if let conversation = model.currentConversation, conversation.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.nWarning)
                }
                Text(model.currentConversation?.title ?? "New Chat")
                    .font(.nBodyMedium)
                    .foregroundStyle(Color.nTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.nTextTertiary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .help("Switch conversation")
    }
}

struct ModelPickerButton: View {
    let model: AppModel

    var body: some View {
        Button {
            model.isModelPickerPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                ProviderGlyph(provider: model.activeSelection.providerID, size: 16)
                Text(model.activeModel.displayName)
                    .font(.nSmallMedium)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.42))
            }
            .padding(.horizontal, 4)
            .frame(height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help("Choose a model")
        .accessibilityLabel("Choose a model. Current: \(model.activeModel.displayName)")
    }
}

struct ModelPickerOverlay: View {
    let model: AppModel
    @State private var refreshing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Choose a model")
                        .font(.nHeadline)
                        .foregroundStyle(Color.white)
                    Text("Model lists are provided by each vendor")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.white.opacity(0.42))
                }
                Spacer()
                if refreshing { Spinner() }
                Button { model.isModelPickerPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .help("Close model picker")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Rectangle().fill(Color(white: 0.16)).frame(height: 0.7)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(AIProviderID.allCases) { provider in
                        providerSection(provider)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }

            Rectangle().fill(Color(white: 0.16)).frame(height: 0.7)

            HStack(spacing: 12) {
                Button {
                    model.isModelPickerPresented = false
                    model.requestSettings(.providers)
                } label: {
                    Label("Manage models", systemImage: "slider.horizontal.3")
                        .font(.nCaption)
                        .foregroundStyle(Color.white.opacity(0.62))
                }
                .buttonStyle(.borderless)
                Spacer()
                Button {
                    refresh()
                } label: {
                    Label("Refresh models", systemImage: "arrow.clockwise")
                        .font(.nCaption)
                        .foregroundStyle(Color.nAccent)
                }
                .buttonStyle(.borderless)
                .disabled(refreshing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private func providerSection(_ provider: AIProviderID) -> some View {
        let candidates = model.catalog.models(for: provider)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                ProviderGlyph(provider: provider, size: 14)
                Text(provider.displayName)
                    .font(.nCaption)
                    .foregroundStyle(Color.white.opacity(0.5))
                if !model.hasAPIKey(provider) {
                    TagView(text: "No key", symbol: "key.slash", tint: .nWarning)
                }
                Spacer()
                Text("\(candidates.count)")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.white.opacity(0.32))
            }
            .padding(.bottom, 3)

            ForEach(candidates) { candidate in
                modelRow(candidate, provider: provider)
            }
        }
    }

    private func modelRow(_ candidate: AIModel, provider: AIProviderID) -> some View {
        let selected = provider == model.activeSelection.providerID
            && candidate.id == model.activeSelection.modelID
        let enabled = model.hasAPIKey(provider)
        return Button {
            model.setModel(ModelSelection(providerID: provider, modelID: candidate.id))
            model.isModelPickerPresented = false
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(candidate.displayName)
                        .font(.nSmall)
                        .foregroundStyle(Color.white.opacity(enabled ? 0.92 : 0.38))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(candidate.id)
                            .lineLimit(1)
                        if let context = candidate.contextWindow {
                            Text("·")
                            Text("\(context / 1000)K")
                        }
                    }
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.white.opacity(0.34))
                }
                Spacer(minLength: 4)
                if candidate.supportsVision {
                    Image(systemName: "eye")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.white.opacity(0.36))
                }
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.nAccent)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 38)
            .overlay(alignment: .leading) {
                if selected {
                    Capsule().fill(Color.nAccent).frame(width: 2, height: 18)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
    }

    private func refresh() {
        guard !refreshing else { return }
        refreshing = true
        Task {
            for provider in model.configuredProviders {
                await model.refreshProviderModels(provider)
            }
            refreshing = false
        }
    }
}
