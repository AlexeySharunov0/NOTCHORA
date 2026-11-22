import NotchoraCore
import SwiftUI

struct HandoffSheet: View {
    let model: AppModel
    let onClose: () -> Void

    @State private var scope: HandoffScope = .fullConversation
    @State private var selectedIDs: Set<UUID> = []
    @State private var target: ModelSelection?
    @State private var contextText = ""
    @State private var isSummarizing = false
    @State private var summaryError: String?
    @State private var autoContinue = true
    @State private var didInitialize = false

    private var conversation: Conversation? { model.currentConversation }

    private var availableTargets: [(AIProviderID, [AIModel])] {
        AIProviderID.allCases.compactMap { provider in
            let models = model.catalog.models(for: provider)
            return models.isEmpty ? nil : (provider, models)
        }
    }

    private var effectiveTarget: ModelSelection {
        target ?? defaultTarget
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    scopeSection
                    if scope == .selectedMessages {
                        messageSelection
                    }
                    targetSection
                    if scope == .summary {
                        summarySection
                    }
                    contextSection
                    options
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }

            footer
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
        .onAppear(perform: initialize)
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.nAccentSoft)
                    .frame(width: 30, height: 30)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.nAccent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Handoff")
                    .font(.nHeadline)
                    .foregroundStyle(Color.nTextPrimary)
                Text("Move this conversation to another model.")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: "What to transfer")
            NotchSegmentedPicker(
                selection: $scope,
                options: HandoffScope.allCases.map { ($0, $0.displayName) }
            )
            .onChange(of: scope) { _, newValue in
                if newValue == .selectedMessages && selectedIDs.isEmpty {
                    selectedIDs = Set(conversation?.messages.map(\.id) ?? [])
                }
                refreshContext()
            }
            Text(scope.detail)
                .font(.nCaptionRegular)
                .foregroundStyle(Color.nTextTertiary)
        }
    }

    private var messageSelection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                SectionLabel(text: "Messages", trailing: "\(selectedIDs.count) selected")
                Button("All") {
                    selectedIDs = Set(conversation?.messages.map(\.id) ?? [])
                    refreshContext()
                }
                .buttonStyle(.plain)
                .font(.nCaption)
                .foregroundStyle(Color.nAccent)
                Button("None") {
                    selectedIDs.removeAll()
                    refreshContext()
                }
                .buttonStyle(.plain)
                .font(.nCaption)
                .foregroundStyle(Color.nTextTertiary)
            }
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(conversation?.messages ?? []) { message in
                        Button {
                            if selectedIDs.contains(message.id) {
                                selectedIDs.remove(message.id)
                            } else {
                                selectedIDs.insert(message.id)
                            }
                            refreshContext()
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: selectedIDs.contains(message.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(selectedIDs.contains(message.id) ? Color.nAccent : Color.nTextTertiary)
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(message.role == .user ? "You" : "Assistant")
                                        .font(.nCaption)
                                        .foregroundStyle(Color.nTextSecondary)
                                    Text(message.content.replacingOccurrences(of: "\n", with: " "))
                                        .font(.nCaptionRegular)
                                        .foregroundStyle(Color.nTextTertiary)
                                        .lineLimit(2)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .hoverHighlight(radius: 7)
                    }
                }
            }
            .frame(maxHeight: 120)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.black)
            )
        }
    }

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: "Continue with")
            Menu {
                ForEach(availableTargets, id: \.0) { provider, models in
                    Section(provider.displayName) {
                        ForEach(models) { model in
                            Button {
                                target = ModelSelection(providerID: provider, modelID: model.id)
                            } label: {
                                HStack {
                                    Text(model.displayName)
                                    if !self.model.hasAPIKey(provider) {
                                        Image(systemName: "key.slash")
                                    }
                                    if provider == effectiveTarget.providerID && model.id == effectiveTarget.modelID {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
                Divider()
                Button("Manage Models…") {
                    self.model.requestSettings(.providers)
                }
            } label: {
                HStack(spacing: 6) {
                    Text("\(effectiveTarget.providerID.shortName) · \(model.catalog.model(for: effectiveTarget).displayName)  ⌄")
                        .font(.nSmallMedium)
                        .foregroundStyle(Color.nTextPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .frame(width: 300, height: 36, alignment: .leading)
                .background(Color.black)
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.nHairline, lineWidth: 0.8)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Text("The receiving model will not be told that it wrote the earlier assistant messages.")
                .font(.nCaptionRegular)
                .foregroundStyle(Color.nTextTertiary)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                SectionLabel(text: "Summary")
                Spacer()
                if isSummarizing {
                    Spinner()
                } else {
                    Button("Generate with \(effectiveTarget.providerID.shortName)") {
                        generateSummary()
                    }
                    .buttonStyle(NButtonStyle(variant: .secondary, compact: true))
                    .disabled(!model.hasAPIKey(effectiveTarget.providerID)
                              || (scope == .selectedMessages && selectedIDs.isEmpty))
                }
            }
            if let summaryError {
                Text(summaryError)
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nDanger)
            }
            Text("A summary reduces context size. Review it before sending; it may omit detail the next model needs.")
                .font(.nCaptionRegular)
                .foregroundStyle(Color.nTextTertiary)
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                SectionLabel(text: "Transferred context")
                Spacer()
                Text("\(contextText.count) characters")
                    .font(.nCaptionRegular)
                    .foregroundStyle(contextText.count > 45_000 ? Color.nWarning : Color.nTextTertiary)
                Button("Reset") {
                    refreshContext()
                }
                .buttonStyle(.plain)
                .font(.nCaption)
                .foregroundStyle(Color.nAccent)
            }
            TextEditor(text: $contextText)
                .font(.nSmall)
                .foregroundStyle(Color.nTextPrimary)
                .scrollContentBackground(.hidden)
                .padding(7)
                .frame(height: 150)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.black)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.nHairline, lineWidth: 0.8)
                }
            if contextText.count > 45_000 {
                Label("This context is very large. The target model may reject it.", systemImage: "exclamationmark.triangle")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nWarning)
            }
        }
    }

    private var options: some View {
        Toggle(isOn: $autoContinue) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Continue automatically")
                    .font(.nSmall)
                    .foregroundStyle(Color.nTextPrimary)
                Text("Send one request to the new model after handoff.")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(Color.nAccent)
    }

    private var footer: some View {
        HStack(spacing: 9) {
            Image(systemName: "lock.shield")
                .font(.system(size: 9))
                .foregroundStyle(Color.nTextTertiary)
            Text("Only the context shown above is sent, to \(effectiveTarget.providerID.displayName).")
                .font(.nCaptionRegular)
                .foregroundStyle(Color.nTextTertiary)
            Spacer()
            Button("Cancel") { onClose() }
                .buttonStyle(NButtonStyle(variant: .ghost))
            Button("Hand off") {
                perform()
            }
            .buttonStyle(NButtonStyle(variant: .primary))
            .disabled(contextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      || (scope == .selectedMessages && selectedIDs.isEmpty)
                      || !model.hasAPIKey(effectiveTarget.providerID))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Hairline() }
    }

    private var defaultTarget: ModelSelection {
        let sourceProvider = conversation?.providerID ?? model.activeSelection.providerID
        if let other = AIProviderID.allCases.first(where: {
            $0 != sourceProvider && model.hasAPIKey($0)
        }) {
            let models = model.catalog.models(for: other)
            if let first = models.first {
                return ModelSelection(providerID: other, modelID: first.id)
            }
        }
        let provider = sourceProvider
        let modelID = conversation?.modelID
            ?? model.catalog.models(for: provider).first?.id
            ?? provider.defaultModelID
        return ModelSelection(providerID: provider, modelID: modelID)
    }

    private func initialize() {
        guard !didInitialize else { return }
        didInitialize = true
        selectedIDs = Set(conversation?.messages.map(\.id) ?? [])
        if target == nil { target = defaultTarget }
        refreshContext()
    }

    private func refreshContext() {
        guard let conversation else { return }
        let summary: String? = scope == .summary ? contextText : nil
        let draft = HandoffBuilder.draft(
            from: conversation,
            scope: scope,
            selectedIDs: selectedIDs,
            summary: summary,
            target: effectiveTarget
        )
        contextText = draft.contextText
    }

    private func generateSummary() {
        guard let conversation else { return }
        isSummarizing = true
        summaryError = nil
        let ids = scope == .selectedMessages ? selectedIDs : []
        Task {
            do {
                let summary = try await model.summarizeForHandoff(
                    conversationID: conversation.id,
                    selectedIDs: ids,
                    summarizer: effectiveTarget
                )
                contextText = summary
            } catch {
                summaryError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isSummarizing = false
        }
    }

    private func perform() {
        guard let conversation else { return }
        var draft = HandoffBuilder.draft(
            from: conversation,
            scope: scope,
            selectedIDs: selectedIDs,
            summary: scope == .summary ? contextText : nil,
            target: effectiveTarget
        )
        draft.contextText = contextText
        model.performHandoff(draft, autoContinue: autoContinue)
        onClose()
    }
}


struct HandoffOverlay: View {
    let model: AppModel

    var body: some View {
        HandoffSheet(model: model) {
            model.isHandoffPresented = false
        }
        .background(Color.black)
    }
}
