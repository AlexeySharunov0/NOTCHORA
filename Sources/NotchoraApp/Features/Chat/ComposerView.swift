import AppKit
import NotchoraCore
import SwiftUI
import UniformTypeIdentifiers

struct ComposerView: View {
    let model: AppModel
    @Binding var draft: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var localFocus = 0
    @State private var editorHeight: CGFloat = 36
    @State private var isDropTarget = false

    private var activeProvider: AIProviderID { model.activeSelection.providerID }
    private var voiceIconColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.62)
    }
    private var hasKey: Bool { model.hasAPIKey(activeProvider) }
    private var isGenerating: Bool { model.isGeneratingCurrent }

    private var canSend: Bool {
        !isGenerating
            && hasKey
            && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.contextDraft != nil)
    }

    var body: some View {
        VStack(spacing: 6) {
            if !hasKey && !model.currentMessages.isEmpty {
                keyNotice
            }

            VStack(spacing: 0) {
                if let context = model.contextDraft {
                    contextChip(context)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                }

                HStack(alignment: .bottom, spacing: 4) {
                    attachmentsMenu
                        .padding(.bottom, 2)

                    ZStack(alignment: .topLeading) {
                        if draft.isEmpty {
                            Text(placeholder)
                                .font(.nBody)
                                .foregroundStyle(Color.nTextTertiary)
                                .padding(.top, 6)
                                .padding(.leading, 2)
                                .allowsHitTesting(false)
                        }
                        PromptEditor(
                            text: $draft,
                            isEnabled: !isGenerating,
                            focusTrigger: model.composerFocusRequest + localFocus,
                            onSubmit: submit,
                            onEscape: { model.collapse() }
                        )
                        .frame(height: editorHeight)
                    }

                    HStack(spacing: 3) {
                        voiceButton
                        sendButton
                    }
                    .padding(.bottom, 1)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 6)

                HStack(spacing: 5) {
                    Text(activeProvider.shortName)
                        .font(.nCaption)
                        .foregroundStyle(Color.nTextTertiary)
                    Text("·")
                        .font(.nCaption)
                        .foregroundStyle(Color.nTextTertiary.opacity(0.6))
                    Text(model.activeModel.displayName)
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                        .lineLimit(1)
                    Spacer()
                    Text("↩ send")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary.opacity(0.7))
                    Text("⇧↩ newline")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary.opacity(0.55))
                }
                .padding(.horizontal, 11)
                .padding(.bottom, 7)
            }
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.nSurfaceRaised.opacity(0.88))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(
                        isDropTarget ? Color.nAccent.opacity(0.6) : Color.nHairlineStrong.opacity(0.65),
                        lineWidth: isDropTarget ? 1.2 : 0.8
                    )
            }
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 5)
        }
        .padding(.horizontal, 14)
        .padding(.top, 7)
        .padding(.bottom, 12)
        .onChange(of: draft) { _, _ in
            updateEditorHeight()
        }
        .onChange(of: model.selectedConversationID) { _, _ in
            draft = ""
            updateEditorHeight()
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $isDropTarget) { providers in
            handleDrop(providers)
        }
    }

    private var placeholder: String {
        if isGenerating {
            return "Generating…"
        }
        return "Ask \(model.activeModel.displayName) anything…"
    }

    private var keyNotice: some View {
        HStack(spacing: 7) {
            Image(systemName: "key.slash")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.nWarning)
            Text("No API key for \(activeProvider.displayName).")
                .font(.nCaption)
                .foregroundStyle(Color.nTextSecondary)
            Spacer()
            Button("Connect") {
                model.requestSettings(.providers)
            }
            .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.nWarning.opacity(0.075))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.nWarning.opacity(0.16), lineWidth: 0.7)
        }
        .padding(.horizontal, 14)
    }

    private var attachmentsMenu: some View {
        Menu {
            Button {
                model.attachClipboardText()
            } label: {
                Label("Use Clipboard Text", systemImage: "doc.on.clipboard")
            }
            Button {
                model.captureSelectedText()
            } label: {
                Label("Ask Selected Text", systemImage: "text.cursor")
            }
            Button {
                model.isScreenCapturePickerPresented = true
            } label: {
                Label("Capture Screen…", systemImage: "rectangle.dashed")
            }
            if model.contextDraft != nil {
                Divider()
                Button(role: .destructive) {
                    model.removeContextAttachment()
                } label: {
                    Label("Remove Context", systemImage: "xmark.circle")
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.nIcon)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.045))
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Add context")
        .accessibilityLabel("Add context")
    }

    private var voiceButton: some View {
        Button {
            model.startVoiceMode()
        } label: {
            Label("Voice Mode", systemImage: "waveform")
                .labelStyle(.iconOnly)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(model.voicePresented ? Color.nAccent : voiceIconColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(model.voicePresented ? Color.nAccentSoft : Color.clear)
                )
        }
        .buttonStyle(.borderless)
        .help("Voice Mode")
        .accessibilityLabel("Voice Mode")
    }

    private var sendButton: some View {
        Button {
            if isGenerating {
                model.cancelGeneration()
            } else {
                submit()
            }
        } label: {
            Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                .font(.system(size: isGenerating ? 9 : 12, weight: .bold))
                .foregroundStyle(isGenerating ? Color.nDanger : (canSend ? Color.white : Color.nTextTertiary))
                .frame(width: 29, height: 29)
                .background(
                    Circle()
                        .fill(
                            isGenerating
                                ? Color.nDanger.opacity(0.12)
                                : (canSend ? Color.nAccent : Color.primary.opacity(0.055))
                        )
                )
                .overlay {
                    Circle()
                        .strokeBorder(
                            isGenerating ? Color.nDanger.opacity(0.22) : Color.white.opacity(canSend ? 0.14 : 0),
                            lineWidth: 0.8
                        )
                }
        }
        .buttonStyle(.plain)
        .disabled(!isGenerating && !canSend)
        .help(isGenerating ? "Stop generating" : "Send message")
        .accessibilityLabel(isGenerating ? "Stop generating" : "Send message")
    }

    @ViewBuilder
    private func contextChip(_ context: ContextDraft) -> some View {
        HStack(spacing: 8) {
            if let attachment = context.attachment, attachment.isImage,
               let image = NSImage(data: attachment.data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 34, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: context.source == .clipboard ? "doc.on.clipboard" : "text.cursor")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.nAccent)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.nAccentSoft))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(context.title)
                    .font(.nCaption)
                    .foregroundStyle(Color.nTextSecondary)
                    .lineLimit(1)
                Text(context.summary)
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                model.removeContextAttachment()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.nTextTertiary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Remove context")
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func submit() {
        guard canSend else {
            if !hasKey {
                model.requestSettings(.providers)
            }
            return
        }
        let text = draft
        draft = ""
        updateEditorHeight()
        model.sendMessage(text)
        localFocus += 1
    }

    private func updateEditorHeight() {
        let explicitLines = draft.components(separatedBy: "\n").count
        let wrappedLines = max(0, draft.count / 54)
        let lines = max(1, explicitLines + wrappedLines)
        let newHeight = min(max(32, CGFloat(lines) * 18 + 8), 126)
        withAnimation(.quick) {
            editorHeight = newHeight
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let itemURL = item as? URL {
                    url = itemURL
                }
                guard let url,
                      let data = try? Data(contentsOf: url),
                      let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType,
                      mime.hasPrefix("image/") else { return }
                let attachment = ChatAttachment(
                    kind: .image,
                    name: url.lastPathComponent,
                    mimeType: mime,
                    data: data
                )
                let name = url.lastPathComponent
                Task { @MainActor in
                    AppEnvironment.shared.model.attachContext(ContextDraft(
                        source: .manual,
                        title: name,
                        text: "",
                        attachment: attachment
                    ))
                }
            }
            return true
        }
        return false
    }
}
