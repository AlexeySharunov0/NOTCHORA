import AppKit
import NotchoraCore
import SwiftUI

struct ChatMessageRow: View {
    let message: ChatMessage
    let model: AppModel
    let isLast: Bool
    var maxBubbleWidth: CGFloat = 430

    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    private var actionColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.48) : Color.black.opacity(0.42)
    }

    var body: some View {
        Group {
            if message.role == .user {
                userMessage
            } else {
                assistantMessage
            }
        }
        .onHover { hovered = $0 }
        .animation(.quick, value: hovered)
    }

    private var userMessage: some View {
        HStack(alignment: .top) {
            Spacer(minLength: 36)
            VStack(alignment: .trailing, spacing: 8) {
                if !message.attachments.isEmpty {
                    attachmentGrid(alignment: .trailing)
                }
                if !message.content.isEmpty {
                    MarkdownView(text: message.content)
                        .font(.nBody)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.nUserBubble)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.nAccent.opacity(0.12), lineWidth: 0.8)
                        }
                }
            }
            .frame(maxWidth: maxBubbleWidth, alignment: .trailing)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("You said")
    }

    private var assistantMessage: some View {
        HStack(alignment: .top, spacing: 9) {
            if let provider = message.providerID {
                ProviderGlyph(provider: provider, size: 20)
                    .padding(.top, 1)
            } else {
                NotchoraMark(size: 20)
                    .padding(.top, 1)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(providerLabel)
                        .font(.nCaption)
                        .foregroundStyle(Color.nTextSecondary)
                    if let modelName {
                        Text(modelName)
                            .font(.nCaptionRegular)
                            .foregroundStyle(actionColor)
                            .lineLimit(1)
                    }
                    if message.status == .cancelled {
                        TagView(text: "Stopped", symbol: "stop.fill", tint: .nWarning)
                    }
                    Spacer(minLength: 0)
                    Text(message.createdAt, style: .time)
                        .font(.nCaptionRegular)
                        .foregroundStyle(actionColor)
                        .opacity(hovered ? 0.75 : 0)
                }

                if message.content.isEmpty {
                    if message.status == .streaming {
                        HStack(spacing: 7) {
                            StreamingDots()
                            Text("Connecting to \(modelName ?? providerLabel)…")
                                .font(.nSmall)
                                .foregroundStyle(actionColor)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    MarkdownView(text: message.content, isStreaming: message.status == .streaming)
                        .frame(maxWidth: 720, alignment: .leading)
                }

                if message.status == .failed {
                    errorCard
                }

                if message.status == .complete || message.status == .streaming || message.status == .cancelled {
                    messageActions
                        .opacity(hovered || message.status == .streaming ? 1 : 0.42)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Assistant response")
    }

    private var errorCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.nDanger)
                    .padding(.top, 1)
                Text(message.errorDescription ?? "The response could not be generated.")
                    .font(.nSmall)
                    .foregroundStyle(Color.nTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 7) {
                Button("Retry") {
                    model.retry(messageID: message.id)
                }
                .buttonStyle(NButtonStyle(variant: .secondary, compact: true))
                .disabled(!isLast)

                Button(model.hasAPIKey(message.providerID ?? model.activeSelection.providerID)
                       ? "Open Settings" : "Connect Provider") {
                    model.requestSettings(.providers)
                }
                .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.nDanger.opacity(0.07))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.nDanger.opacity(0.18), lineWidth: 0.8)
        }
    }

    private var messageActions: some View {
        HStack(spacing: 4) {
            Button {
                model.copyToClipboard(message.content)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(actionColor)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Copy response")

            if message.status == .streaming {
                Button {
                    model.cancelGeneration()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.nDanger)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Stop generating")
            } else if isLast {
                Button {
                    model.regenerateLastResponse()
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(actionColor)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Regenerate response")
            }

            if let metadata = metadataLabel {
                Text(metadata)
                    .font(.nCaptionRegular)
                    .foregroundStyle(actionColor)
                    .padding(.leading, 3)
            }
            Spacer()
        }
    }

    private var providerLabel: String {
        message.providerID?.shortName ?? "NOTCHORA"
    }

    private var modelName: String? {
        guard let providerID = message.providerID, let modelID = message.modelID else { return nil }
        return model.catalog.model(for: ModelSelection(providerID: providerID, modelID: modelID)).displayName
    }

    private var metadataLabel: String? {
        guard message.status == .complete else { return nil }
        var parts: [String] = []
        if let duration = message.duration {
            parts.append(String(format: "%.1fs", duration))
        }
        if let total = message.usage?.totalTokens {
            parts.append("\(total) tokens")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func attachmentGrid(alignment: HorizontalAlignment) -> some View {
        let images = message.attachments.filter(\.isImage)
        let documents = message.attachments.filter { !$0.isImage }
        VStack(alignment: alignment, spacing: 5) {
            if !images.isEmpty {
                HStack(spacing: 6) {
                    ForEach(images.prefix(3)) { attachment in
                        AttachmentThumbnail(attachment: attachment)
                    }
                }
            }
            ForEach(documents) { attachment in
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 9))
                    Text(attachment.name)
                        .font(.nCaption)
                        .lineLimit(1)
                    Text("\(max(1, attachment.byteCount / 1024)) KB")
                        .font(.nCaptionRegular)
                        .foregroundStyle(actionColor)
                }
                .foregroundStyle(Color.nTextSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.045))
                )
            }
        }
    }
}

struct AttachmentThumbnail: View {
    let attachment: ChatAttachment

    var body: some View {
        if let image = NSImage(data: attachment.data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 112, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
                }
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .onTapGesture {
                    openInPreview()
                }
                .help("Open full image")
        }
    }

    private func openInPreview() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NOTCHORA", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(attachment.name)
        do {
            try attachment.data.write(to: file, options: .atomic)
            NSWorkspace.shared.open(file)
        } catch {
            NSSound.beep()
        }
    }
}
