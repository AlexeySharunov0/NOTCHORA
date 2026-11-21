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
        .background(Color.nPanel.opacity(0.30))
        .overlay(alignment: .bottom) { Hairline() }
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
        colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.62)
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

    @State private var presented = false

    var body: some View {
        Button {
            presented.toggle()
        } label: {
            HStack(spacing: 6) {
                ProviderGlyph(provider: model.activeSelection.providerID, size: 16)
                Text(model.activeModel.displayName)
                    .font(.nSmallMedium)
                    .foregroundStyle(Color.nTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(Color.nTextTertiary)
            }
            .padding(.horizontal, 7)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(presented ? Color.nAccentSoft : Color.primary.opacity(0.045))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        presented ? Color.nAccent.opacity(0.25) : Color.nHairline,
                        lineWidth: 0.7
                    )
            }
        }
        .buttonStyle(.plain)
        .help("Choose a model")
        .accessibilityLabel("Choose a model. Current: \(model.activeModel.displayName)")
        .popover(isPresented: $presented, arrowEdge: .bottom) {
            ModelPickerPopover(model: model, presented: $presented)
        }
        .onChange(of: presented) { _, isPresented in
            model.isTransientUIPresented = isPresented
        }
        .onDisappear {
            model.isTransientUIPresented = false
        }
    }
}

struct ModelPickerPopover: View {
    let model: AppModel
    @Binding var presented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Text("Model")
                    .font(.nSmallMedium)
                    .foregroundStyle(Color.nTextPrimary)
                Spacer()
                Text("Provider lists update from the API")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 11)
            .padding(.bottom, 8)

            Hairline()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(AIProviderID.allCases) { provider in
                        providerSection(provider)
                    }
                }
                .padding(7)
            }
            .frame(maxHeight: 360)

            Hairline()

            HStack {
                Button {
                    presented = false
                    model.requestSettings(.providers)
                } label: {
                    Label("Manage Models…", systemImage: "slider.horizontal.3")
                        .font(.nCaption)
                        .foregroundStyle(Color.nTextSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Refresh") {
                    Task {
                        for provider in model.configuredProviders {
                            await model.refreshProviderModels(provider)
                        }
                    }
                }
                .buttonStyle(.plain)
                .font(.nCaption)
                .foregroundStyle(Color.nAccent)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
        }
        .frame(width: 322)
        .background(Color.nPanelSolid)
    }

    private func providerSection(_ provider: AIProviderID) -> some View {
        let candidates = model.catalog.models(for: provider)
        return VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                ProviderGlyph(provider: provider, size: 14)
                Text(provider.displayName)
                    .font(.nCaption)
                    .foregroundStyle(Color.nTextSecondary)
                if !model.hasAPIKey(provider) {
                    TagView(text: "No key", symbol: "key.slash", tint: .nWarning)
                }
                Spacer()
                Text("\(candidates.count)")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 2)

            ForEach(candidates) { candidate in
                modelRow(candidate, provider: provider)
            }
        }
        .padding(.bottom, 3)
    }

    private func modelRow(_ candidate: AIModel, provider: AIProviderID) -> some View {
        let selected = provider == model.activeSelection.providerID
            && candidate.id == model.activeSelection.modelID
        return Button {
            model.setModel(ModelSelection(providerID: provider, modelID: candidate.id))
            presented = false
        } label: {
            HStack(spacing: 7) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(candidate.displayName)
                        .font(.nSmall)
                        .foregroundStyle(Color.nTextPrimary)
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
                    .foregroundStyle(Color.nTextTertiary)
                }
                Spacer(minLength: 4)
                if candidate.supportsVision {
                    Image(systemName: "eye")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.nTextTertiary)
                }
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.nAccent)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selected ? Color.nAccentSoft : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(radius: 6)
        .disabled(!model.hasAPIKey(provider))
        .opacity(model.hasAPIKey(provider) ? 1 : 0.55)
    }
}
