import NotchoraCore
import SwiftUI

struct MultiAIView: View {
    let model: AppModel

    @State private var prompt = ""
    @State private var selectedModelIDs: Set<String> = []
    @State private var isComposingNew = false
    @State private var compareSheetPresented = false
    @State private var didInitialize = false

    private var isSetup: Bool {
        model.multiAI == nil || model.multiAI?.prompt.isEmpty == true || isComposingNew
    }

    private var selectedModels: [AIModel] {
        AIProviderID.allCases.flatMap { provider in
            model.catalog.models(for: provider).filter {
                selectedModelIDs.contains(qualifiedID(provider: provider, modelID: $0.id))
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if isSetup {
                setup
            } else if let session = model.multiAI {
                sessionView(session)
            }
        }
        .onAppear(perform: initialize)
        .sheet(isPresented: $compareSheetPresented) {
            CompareAnswersSheet(model: model)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                model.navigate(.chat)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.nTextSecondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.primary.opacity(0.045)))
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 1) {
                Text("Multi-AI")
                    .font(.nHeadline)
                    .foregroundStyle(Color.nTextPrimary)
                Text(isSetup
                     ? "One prompt, independent answers"
                     : "\(model.multiAI?.models.count ?? 0) models in parallel")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
            Spacer()

            if !isSetup {
                Button {
                    compareSheetPresented = true
                } label: {
                    Label("Compare", systemImage: "arrow.left.arrow.right")
                }
                .buttonStyle(NButtonStyle(variant: .secondary, compact: true))
                .disabled((model.multiAI?.completedModels.count ?? 0) < 2)
                .help("Compare completed answers with another model")

                Button {
                    model.saveMultiAIResults()
                } label: {
                    Label(model.multiAI?.savedConversationID == nil ? "Save" : "Saved",
                          systemImage: model.multiAI?.savedConversationID == nil ? "tray.and.arrow.down" : "checkmark")
                }
                .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
                .disabled((model.multiAI?.completedModels.isEmpty ?? true)
                          || model.multiAI?.savedConversationID != nil)
            }

            Button {
                newSession()
            } label: {
                Label("New", systemImage: "plus")
            }
            .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
        }
        .padding(.horizontal, 13)
        .frame(height: 46)
        .background(Color.nPanel.opacity(0.30))
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var setup: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Send the same prompt to several models. Each stream is independent; cancel, retry, or save results separately.")
                    .font(.nSmall)
                    .foregroundStyle(Color.nTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Prompt")
                    ZStack(alignment: .topLeading) {
                        if prompt.isEmpty {
                            Text("Ask the models something…")
                                .font(.nBody)
                                .foregroundStyle(Color.nTextTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $prompt)
                            .font(.nBody)
                            .scrollContentBackground(.hidden)
                            .padding(2)
                            .frame(height: 96)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.nSurfaceSunken.opacity(0.5))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.nHairline, lineWidth: 0.8)
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    SectionLabel(text: "Models", trailing: "\(selectedModels.count) selected")
                    ForEach(AIProviderID.allCases) { provider in
                        let providerModels = model.catalog.models(for: provider)
                        if !providerModels.isEmpty {
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 5) {
                                    ProviderGlyph(provider: provider, size: 15)
                                    Text(provider.displayName)
                                        .font(.nCaption)
                                        .foregroundStyle(Color.nTextSecondary)
                                    if !model.hasAPIKey(provider) {
                                        TagView(text: "No key", symbol: "key.slash", tint: .nWarning)
                                    }
                                }
                                .padding(.top, 4)
                                .padding(.bottom, 2)

                                ForEach(providerModels) { candidate in
                                    modelRow(candidate, provider: provider)
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9))
                    Text("Every selected model receives the prompt independently. Provider pricing applies to each call.")
                        .font(.nCaptionRegular)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Color.nTextTertiary)
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("\(selectedModels.count) model\(selectedModels.count == 1 ? "" : "s")")
                    .font(.nCaption)
                    .foregroundStyle(Color.nTextTertiary)
                Spacer()
                Button("Start Multi-AI") {
                    start()
                }
                .buttonStyle(NButtonStyle(variant: .primary))
                .disabled(!canStart)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            .overlay(alignment: .top) { Hairline() }
        }
    }

    private func modelRow(_ candidate: AIModel, provider: AIProviderID) -> some View {
        let id = qualifiedID(provider: provider, modelID: candidate.id)
        let selected = selectedModelIDs.contains(id)
        let allowed = model.hasAPIKey(provider)
        return Button {
            if selected {
                selectedModelIDs.remove(id)
            } else {
                selectedModelIDs.insert(id)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12))
                    .foregroundStyle(selected ? Color.nAccent : Color.nTextTertiary)
                Text(candidate.displayName)
                    .font(.nSmall)
                    .foregroundStyle(allowed ? Color.nTextPrimary : Color.nTextTertiary)
                if candidate.supportsVision {
                    TagView(text: "Vision", tint: .nTeal)
                }
                Spacer()
                if !allowed {
                    Text("Connect a key")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 29)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.nAccentSoft : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!allowed)
    }

    private func sessionView(_ session: MultiAISession) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.nTextTertiary)
                        .padding(.top, 2)
                    Text(session.prompt)
                        .font(.nSmall)
                        .foregroundStyle(Color.nTextSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if session.isRunning {
                        Spinner()
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )

                if let comparison = session.comparison {
                    comparisonCard(comparison, prompt: session.prompt)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 300), spacing: 9, alignment: .top)],
                    spacing: 9
                ) {
                    ForEach(session.models) { target in
                        responseCard(target)
                    }
                }

                if session.models.contains(where: { $0.isRunning }) {
                    Text("Responses stream independently. You can cancel one model without stopping the others.")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                }
            }
            .padding(12)
        }
    }

    private func responseCard(_ target: MultiAIModelState) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                ProviderGlyph(provider: target.selection.providerID, size: 17)
                Text(target.model.displayName)
                    .font(.nCaption)
                    .foregroundStyle(Color.nTextPrimary)
                    .lineLimit(1)
                Spacer()
                if target.isRunning {
                    Button {
                        model.cancelMultiAITarget(target.id)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Color.nDanger)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.borderless)
                    .help("Cancel this model")
                } else if target.status == .failed || target.status == .cancelled {
                    Button {
                        model.retryMultiAITarget(target.id)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.nTextSecondary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.borderless)
                    .help("Retry this model")
                }
                MultiAIStatusPill(status: target.status)
            }

            Hairline()

            if target.text.isEmpty {
                VStack(spacing: 6) {
                    switch target.status {
                    case .failed:
                        Text(target.errorDescription ?? "Generation failed.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nDanger)
                            .fixedSize(horizontal: false, vertical: true)
                    case .cancelled:
                        Text("Stopped.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    case .waiting, .idle:
                        HStack(spacing: 6) {
                            Spinner()
                            Text("Connecting…")
                                .font(.nCaption)
                                .foregroundStyle(Color.nTextTertiary)
                        }
                    case .streaming:
                        HStack(spacing: 6) {
                            StreamingDots()
                            Text("Generating…")
                                .font(.nCaption)
                                .foregroundStyle(Color.nTextTertiary)
                        }
                    case .completed:
                        Text("Empty response.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    MarkdownView(text: target.text, isStreaming: target.status == .streaming)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
            }

            if target.status == .failed, !target.text.isEmpty, let error = target.errorDescription {
                Text(error)
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nDanger)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                if let usage = target.usage?.totalTokens {
                    Text("\(usage) tokens")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                }
                Spacer()
                if !target.text.isEmpty {
                    Button {
                        model.copyToClipboard(target.text)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.nTextTertiary)
                            .frame(width: 20, height: 18)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy this response")
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.nSurfaceRaised.opacity(0.5))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    target.isRunning ? Color.nAccent.opacity(0.20) : Color.nHairline,
                    lineWidth: 0.8
                )
        }
    }

    private func comparisonCard(_ comparison: ComparisonState, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.nAccent)
                Text("Compare Answers")
                    .font(.nSmallMedium)
                    .foregroundStyle(Color.nTextPrimary)
                Text("· \(comparison.selection.providerID.shortName) · \(model.catalog.model(for: comparison.selection).displayName)")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                    .lineLimit(1)
                Spacer()
                if comparison.status == .streaming {
                    Button("Cancel") { model.cancelComparison() }
                        .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
                } else if comparison.status == .failed {
                    Text(comparison.errorDescription ?? "Failed")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nDanger)
                } else if comparison.status == .completed {
                    Button {
                        model.copyToClipboard(comparison.text)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            if comparison.status == .streaming && comparison.text.isEmpty {
                HStack(spacing: 6) {
                    StreamingDots()
                    Text("Synthesizing a comparison…")
                        .font(.nCaption)
                        .foregroundStyle(Color.nTextTertiary)
                }
            } else if !comparison.text.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    MarkdownView(text: comparison.text, isStreaming: comparison.status == .streaming)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
            }
            Text("Model-generated comparison, not an objective fact check.")
                .font(.nCaptionRegular)
                .foregroundStyle(Color.nTextTertiary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.nAccentSoft.opacity(0.55))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.nAccent.opacity(0.18), lineWidth: 0.8)
        }
    }

    private var canStart: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedModels.isEmpty
            && selectedModels.allSatisfy { model.hasAPIKey($0.providerID) }
    }

    private func start() {
        let models = selectedModels
        guard !models.isEmpty else { return }
        model.startMultiAI(prompt: prompt, models: models)
        isComposingNew = false
    }

    private func newSession() {
        model.clearMultiAI()
        isComposingNew = true
        prompt = ""
        selectedModelIDs = [qualifiedID(
            provider: model.activeSelection.providerID,
            modelID: model.activeSelection.modelID
        )]
    }

    private func initialize() {
        guard !didInitialize else { return }
        didInitialize = true
        if let session = model.multiAI, !session.prompt.isEmpty {
            isComposingNew = false
            selectedModelIDs = Set(session.models.map {
                qualifiedID(provider: $0.selection.providerID, modelID: $0.selection.modelID)
            })
        } else {
            isComposingNew = true
            if selectedModelIDs.isEmpty {
                selectedModelIDs = [qualifiedID(
                    provider: model.activeSelection.providerID,
                    modelID: model.activeSelection.modelID
                )]
            }
        }
    }

    private func qualifiedID(provider: AIProviderID, modelID: String) -> String {
        "\(provider.rawValue)/\(modelID)"
    }
}

struct MultiAIStatusPill: View {
    let status: MultiAIStatus

    var body: some View {
        HStack(spacing: 3) {
            if status == .streaming || status == .waiting {
                Spinner()
                    .frame(width: 7, height: 7)
                    .scaleEffect(0.6)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
            }
            Text(status.label)
                .font(.nCaption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2.5)
        .background(Capsule().fill(color.opacity(0.08)))
    }

    private var color: Color {
        switch status {
        case .idle, .waiting: .nTextTertiary
        case .streaming: .nAccent
        case .completed: .nSuccess
        case .failed: .nDanger
        case .cancelled: .nWarning
        }
    }
}

struct CompareAnswersSheet: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var target = ModelSelection(providerID: .openAI, modelID: AIProviderID.openAI.defaultModelID)
    @State private var didInitialize = false

    private var session: MultiAISession? { model.multiAI }
    private var comparison: ComparisonState? { session?.comparison }

    var body: some View {
        VStack(spacing: 0) {
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
                    Text("Compare Answers")
                        .font(.nHeadline)
                        .foregroundStyle(Color.nTextPrimary)
                    Text("Find contradictions, errors, and strengths")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.nTextTertiary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(.borderless)
            }
            .padding(16)
            .overlay(alignment: .bottom) { Hairline() }

            VStack(alignment: .leading, spacing: 12) {
                Text("A third model reads the completed responses and compares them. This is a model-generated analysis, not verified fact-checking.")
                    .font(.nSmall)
                    .foregroundStyle(Color.nTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                SectionLabel(text: "Analyze with")
                Menu {
                    ForEach(AIProviderID.allCases) { provider in
                        Section(provider.displayName) {
                            ForEach(model.catalog.models(for: provider)) { candidate in
                                Button {
                                    target = ModelSelection(providerID: provider, modelID: candidate.id)
                                } label: {
                                    HStack {
                                        Text(candidate.displayName)
                                        if !model.hasAPIKey(provider) {
                                            Image(systemName: "key.slash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        ProviderGlyph(provider: target.providerID, size: 18)
                        Text(model.catalog.model(for: target).displayName)
                            .font(.nSmallMedium)
                            .foregroundStyle(Color.nTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.primary.opacity(0.035))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.nHairline, lineWidth: 0.8)
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                SectionLabel(text: "Inputs")
                ForEach(session?.completedModels ?? []) { answer in
                    HStack(spacing: 7) {
                        ProviderGlyph(provider: answer.selection.providerID, size: 15)
                        Text(answer.model.displayName)
                            .font(.nCaption)
                            .foregroundStyle(Color.nTextSecondary)
                        Spacer()
                        Text("\(answer.text.count) chars")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                }

                if let comparison {
                    SectionLabel(text: "Analysis")
                    if comparison.status == .streaming && comparison.text.isEmpty {
                        HStack(spacing: 6) {
                            StreamingDots()
                            Text("Comparing…")
                                .font(.nCaption)
                                .foregroundStyle(Color.nTextTertiary)
                        }
                    } else if !comparison.text.isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            MarkdownView(text: comparison.text, isStreaming: comparison.status == .streaming)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 250)
                        .padding(9)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.nSurfaceSunken.opacity(0.45))
                        )
                    } else if comparison.status == .failed {
                        Text(comparison.errorDescription ?? "Comparison failed.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nDanger)
                    }
                }
            }
            .padding(16)

            HStack {
                if let comparison, comparison.status == .streaming {
                    Button("Cancel") { model.cancelComparison() }
                        .buttonStyle(NButtonStyle(variant: .ghost))
                }
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(NButtonStyle(variant: .ghost))
                Button("Start Comparison") {
                    model.startComparison(selection: target)
                }
                .buttonStyle(NButtonStyle(variant: .primary))
                .disabled((session?.completedModels.count ?? 0) < 2
                          || !model.hasAPIKey(target.providerID)
                          || comparison?.status == .streaming)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Hairline() }
        }
        .frame(width: 560, height: 620)
        .background(Color.nPanelSolid)
        .onAppear(perform: initialize)
    }

    private func initialize() {
        guard !didInitialize else { return }
        didInitialize = true
        if let first = session?.completedModels.first {
            target = first.selection
        } else if let selected = model.multiAI?.models.first?.selection {
            target = selected
        }
    }
}
