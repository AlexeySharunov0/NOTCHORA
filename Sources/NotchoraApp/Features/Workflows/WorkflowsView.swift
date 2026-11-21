import NotchoraCore
import SwiftUI

struct WorkflowsView: View {
    let model: AppModel

    @State private var runSheetWorkflow: Workflow?
    @State private var deleteTarget: Workflow?

    private var editorBinding: Binding<Workflow?> {
        Binding(get: { model.workflowEditor }, set: { model.workflowEditor = $0 })
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let run = model.workflowRun, run.status == .streaming || run.status == .failed {
                runningCard(run)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
            }

            if model.workflows.isEmpty {
                EmptyStateView(
                    symbol: "point.3.connected.trianglepath.dotted",
                    title: "No workflows",
                    message: "Chain models into a repeatable sequence. Each step runs with a real API call."
                )
                .overlay(alignment: .bottom) {
                    Button("Create Workflow") {
                        model.workflowEditor = model.workflowDraft()
                    }
                    .buttonStyle(NButtonStyle(variant: .primary))
                    .padding(.bottom, 60)
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 7) {
                        ForEach(model.workflows) { workflow in
                            workflowCard(workflow)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                }
            }
        }
        .sheet(item: $runSheetWorkflow) { workflow in
            WorkflowRunSheet(model: model, workflow: workflow)
        }
        .sheet(item: editorBinding) { workflow in
            WorkflowEditorView(model: model, workflow: workflow)
        }
        .alert(
            "Delete workflow?",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    model.deleteWorkflow(target.id)
                }
                deleteTarget = nil
            }
        } message: {
            Text("This removes the workflow definition. Past task results are kept.")
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
                Text("Workflows")
                    .font(.nHeadline)
                    .foregroundStyle(Color.nTextPrimary)
                Text("Sequential, repeatable AI runs")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
            Spacer()
            Button {
                model.workflowEditor = model.workflowDraft()
            } label: {
                Label("New", systemImage: "plus")
            }
            .buttonStyle(NButtonStyle(variant: .secondary, compact: true))
        }
        .padding(.horizontal, 13)
        .frame(height: 46)
        .background(Color.nPanel.opacity(0.30))
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func workflowCard(_ workflow: Workflow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.nAccentSoft)
                    .frame(width: 35, height: 35)
                Image(systemName: workflow.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.nAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(workflow.name)
                        .font(.nSmallMedium)
                        .foregroundStyle(Color.nTextPrimary)
                        .lineLimit(1)
                    if model.workflowRun?.workflowID == workflow.id,
                       model.workflowRun?.status == .streaming {
                        TaskStatusPill(status: .running)
                    }
                }
                Text(workflow.summary)
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    Text("\(workflow.steps.count) steps")
                    Text("·")
                    ForEach(Array(Set(workflow.steps.map(\.providerID))), id: \.self) { provider in
                        ProviderGlyph(provider: provider, size: 13)
                    }
                }
                .font(.nCaptionRegular)
                .foregroundStyle(Color.nTextTertiary)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 5) {
                Button("Run") {
                    runSheetWorkflow = workflow
                }
                .buttonStyle(NButtonStyle(variant: .secondary, compact: true))
                .disabled(model.workflowRun?.status == .streaming)

                Menu {
                    Button {
                        model.workflowEditor = workflow
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button {
                        model.duplicateWorkflow(workflow)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Divider()
                    Button(role: .destructive) {
                        deleteTarget = workflow
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.nTextTertiary)
                        .frame(width: 22, height: 20)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(0.028))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.nHairline.opacity(0.8), lineWidth: 0.7)
        }
    }

    private func runningCard(_ run: WorkflowRunDisplay) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                if run.status == .streaming {
                    Spinner()
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.nDanger)
                }
                Text(run.workflowName)
                    .font(.nSmallMedium)
                    .foregroundStyle(Color.nTextPrimary)
                Spacer()
                Text(run.currentStep)
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                    .lineLimit(1)
                if run.status == .streaming {
                    Button("Cancel") {
                        model.cancelWorkflowRun()
                    }
                    .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
                }
            }
            if run.status == .streaming {
                IndeterminateProgressBar()
            }
            if let error = run.errorDescription {
                Text(error)
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nDanger)
                    .lineLimit(2)
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.nAccentSoft.opacity(0.6))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.nAccent.opacity(0.16), lineWidth: 0.8)
        }
    }
}

struct WorkflowRunSheet: View {
    let model: AppModel
    let workflow: Workflow

    @Environment(\.dismiss) private var dismiss
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.nAccentSoft)
                        .frame(width: 30, height: 30)
                    Image(systemName: workflow.symbolName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.nAccent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(workflow.name)
                        .font(.nHeadline)
                        .foregroundStyle(Color.nTextPrimary)
                    Text(workflow.summary)
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                        .lineLimit(1)
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
                SectionLabel(text: "Input")
                TextEditor(text: $input)
                    .font(.nSmall)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 150)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.nSurfaceSunken.opacity(0.55))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.nHairline, lineWidth: 0.8)
                    }
                if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Paste code, text, or a question. The first step receives this input.")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                }

                SectionLabel(text: "Sequence")
                VStack(spacing: 4) {
                    ForEach(Array(workflow.steps.enumerated()), id: \.element.id) { index, step in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.nTextTertiary)
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(Color.primary.opacity(0.05)))
                            ProviderGlyph(provider: step.providerID, size: 16)
                            Text(step.name)
                                .font(.nCaption)
                                .foregroundStyle(Color.nTextSecondary)
                            Spacer()
                            if !model.hasAPIKey(step.providerID) {
                                TagView(text: "No key", symbol: "key.slash", tint: .nWarning)
                            }
                            Text(step.modelID)
                                .font(.nCaptionRegular)
                                .foregroundStyle(Color.nTextTertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Label("Each step makes a real API request. Longer workflows use more tokens.", systemImage: "info.circle")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
            .padding(16)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(NButtonStyle(variant: .ghost))
                Spacer()
                Button("Run Workflow") {
                    dismiss()
                    model.runWorkflow(workflow, input: input)
                }
                .buttonStyle(NButtonStyle(variant: .primary))
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Hairline() }
        }
        .frame(width: 520, height: 540)
        .background(Color.nPanelSolid)
    }
}

struct WorkflowEditorView: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var workflow: Workflow

    init(model: AppModel, workflow: Workflow) {
        self.model = model
        _workflow = State(initialValue: workflow)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    labelledField("Name") {
                        TextField("Workflow name", text: $workflow.name)
                            .textFieldStyle(.roundedBorder)
                    }
                    labelledField("Summary") {
                        TextField("What this workflow does", text: $workflow.summary)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        SectionLabel(text: "Steps", trailing: "\(workflow.steps.count)")
                        Spacer()
                        Button {
                            addStep()
                        } label: {
                            Label("Add Step", systemImage: "plus")
                        }
                        .buttonStyle(NButtonStyle(variant: .secondary, compact: true))
                    }

                    ForEach(Array(workflow.steps.enumerated()), id: \.element.id) { index, _ in
                        stepEditor(index)
                    }

                    if workflow.steps.isEmpty {
                        Text("Add at least one step to save this workflow.")
                            .font(.nSmall)
                            .foregroundStyle(Color.nWarning)
                    }
                }
                .padding(16)
            }

            HStack {
                if !workflow.steps.isEmpty {
                    Text("\(workflow.steps.count) step\(workflow.steps.count == 1 ? "" : "s")")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(NButtonStyle(variant: .ghost))
                Button("Save Workflow") {
                    model.saveWorkflow(workflow)
                    dismiss()
                }
                .buttonStyle(NButtonStyle(variant: .primary))
                .disabled(workflow.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || workflow.steps.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Hairline() }
        }
        .frame(width: 680, height: 680)
        .background(Color.nPanelSolid)
    }

    private var header: some View {
        HStack(spacing: 9) {
            NotchoraMark(size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("Workflow Editor")
                    .font(.nHeadline)
                    .foregroundStyle(Color.nTextPrimary)
                Text("Edits are local until you save.")
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
    }

    private func stepEditor(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Step \(index + 1)")
                    .font(.nCaption)
                    .foregroundStyle(Color.nTextTertiary)
                TextField("Step name", text: $workflow.steps[index].name)
                    .textFieldStyle(.plain)
                    .font(.nSmallMedium)
                Spacer()
                NIconButton(symbol: "chevron.up", label: "Move up", size: 20) {
                    moveStep(index, by: -1)
                }
                .disabled(index == 0)
                NIconButton(symbol: "chevron.down", label: "Move down", size: 20) {
                    moveStep(index, by: 1)
                }
                .disabled(index >= workflow.steps.count - 1)
                NIconButton(symbol: "trash", label: "Delete step", size: 20, tint: .nDanger) {
                    workflow.steps.remove(at: index)
                }
            }

            HStack(spacing: 8) {
                Menu {
                    ForEach(AIProviderID.allCases) { provider in
                        Section(provider.displayName) {
                            ForEach(model.catalog.models(for: provider)) { candidate in
                                Button {
                                    workflow.steps[index].providerID = provider
                                    workflow.steps[index].modelID = candidate.id
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
                    HStack(spacing: 6) {
                        ProviderGlyph(provider: workflow.steps[index].providerID, size: 16)
                        Text(model.catalog.model(for: ModelSelection(
                            providerID: workflow.steps[index].providerID,
                            modelID: workflow.steps[index].modelID
                        )).displayName)
                            .font(.nCaption)
                            .foregroundStyle(Color.nTextSecondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    .padding(.horizontal, 7)
                    .frame(height: 25)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                Menu {
                    ForEach(WorkflowStep.InputSource.allCases, id: \.self) { source in
                        Button {
                            workflow.steps[index].inputSource = source
                        } label: {
                            if workflow.steps[index].inputSource == source {
                                Label(source.displayName, systemImage: "checkmark")
                            } else {
                                Text(source.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 8))
                        Text(workflow.steps[index].inputSource.displayName)
                            .font(.nCaption)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                    }
                    .foregroundStyle(Color.nTextSecondary)
                    .padding(.horizontal, 7)
                    .frame(height: 25)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                Spacer()
            }

            Text("Prompt · use {{input}} to place the selected input")
                .font(.nCaptionRegular)
                .foregroundStyle(Color.nTextTertiary)
            TextEditor(text: $workflow.steps[index].promptTemplate)
                .font(.nCodeSmall)
                .scrollContentBackground(.hidden)
                .padding(7)
                .frame(height: 82)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.nSurfaceSunken.opacity(0.5))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.nHairline, lineWidth: 0.7)
                }

            DisclosureGroup("System prompt (optional)") {
                TextEditor(text: $workflow.steps[index].systemPrompt)
                    .font(.nCodeSmall)
                    .scrollContentBackground(.hidden)
                    .padding(7)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.nSurfaceSunken.opacity(0.5))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.nHairline, lineWidth: 0.7)
                    }
            }
            .font(.nCaption)
            .foregroundStyle(Color.nTextSecondary)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.nHairline, lineWidth: 0.7)
        }
    }

    private func labelledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel(text: label)
            content()
        }
    }

    private func addStep() {
        let provider = model.settings.defaultProviderID
        let modelID = model.catalog.models(for: provider).first?.id ?? provider.defaultModelID
        workflow.steps.append(WorkflowStep(
            name: "Step \(workflow.steps.count + 1)",
            providerID: provider,
            modelID: modelID,
            promptTemplate: "{{input}}",
            inputSource: workflow.steps.isEmpty ? .originalRequest : .previousStep
        ))
    }

    private func moveStep(_ index: Int, by offset: Int) {
        let target = index + offset
        guard workflow.steps.indices.contains(target) else { return }
        workflow.steps.swapAt(index, target)
    }
}
