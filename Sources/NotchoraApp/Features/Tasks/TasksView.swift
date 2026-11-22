import NotchoraCore
import SwiftUI

private enum TaskFilter: String, CaseIterable, Identifiable {
    case active
    case all

    var id: String { rawValue }
    var title: String { self == .active ? "Active" : "All" }
}

struct TasksView: View {
    let model: AppModel

    @State private var filter: TaskFilter = .all
    @State private var expanded: Set<UUID> = []

    private var visibleTasks: [AITask] {
        let sorted = model.tasks.sortedTasks
        switch filter {
        case .active:
            return sorted.filter { !$0.status.isTerminal }
        case .all:
            return sorted
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            HStack(spacing: 8) {
                NotchSegmentedPicker(
                    selection: $filter,
                    options: TaskFilter.allCases.map { ($0, $0.title) }
                )
                .frame(width: 150)
                Spacer()
                if model.tasks.tasks.contains(where: { $0.status.isTerminal }) {
                    Button("Clear Finished") {
                        model.tasks.clearFinished()
                        model.scheduleSave()
                    }
                    .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)

            if visibleTasks.isEmpty {
                EmptyStateView(
                    symbol: "checklist",
                    title: filter == .active ? "No active tasks" : "No tasks yet",
                    message: "Chat generations, Multi-AI runs, comparisons, and workflows appear here while they run and after they finish."
                )
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 5) {
                        ForEach(visibleTasks) { task in
                            taskRow(task)
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.bottom, 12)
                }
            }
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
                    .background(Circle().fill(Color.black))
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 1) {
                Text("Tasks")
                    .font(.nHeadline)
                    .foregroundStyle(Color.nTextPrimary)
                Text(model.tasks.hasRunningTasks
                     ? "\(model.tasks.runningCount) running · background work continues when the panel closes"
                     : "Background AI work and its local results")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                    .lineLimit(1)
            }
            Spacer()
            if model.tasks.hasRunningTasks {
                Button("Stop All") {
                    model.tasks.cancelAll()
                    model.scheduleSave()
                }
                .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 46)
        .background(Color.black)
    }

    private func taskRow(_ task: AITask) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(statusColor(task.status).opacity(0.10))
                        .frame(width: 27, height: 27)
                    Image(systemName: kindSymbol(task.kind))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(statusColor(task.status))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .font(.nSmallMedium)
                        .foregroundStyle(Color.nTextPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(task.providerID.shortName)
                        Text("·")
                        Text(task.modelID)
                            .lineLimit(1)
                    }
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                }

                Spacer()

                TaskStatusPill(status: task.status)

                if !task.status.isTerminal {
                    NIconButton(symbol: "stop.fill", label: "Cancel task", size: 22, tint: .nDanger) {
                        model.tasks.cancel(task.id)
                        model.scheduleSave()
                    }
                } else {
                    NIconButton(symbol: "trash", label: "Remove task", size: 22) {
                        model.tasks.remove(task.id)
                        model.scheduleSave()
                    }
                }
            }

            if task.status == .running || task.status == .pending {
                IndeterminateProgressBar(tint: statusColor(task.status))
            }

            if let error = task.errorDescription, task.status == .failed || task.status == .cancelled {
                Text(error)
                    .font(.nCaptionRegular)
                    .foregroundStyle(task.status == .failed ? Color.nDanger : Color.nTextTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !task.result.isEmpty {
                if expanded.contains(task.id) {
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(task.result)
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 130)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black)
                    )
                } else {
                    Text(task.result.replacingOccurrences(of: "\n", with: " "))
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 10) {
                Label(task.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                if let duration = task.duration {
                    Label(String(format: "%.1fs", duration), systemImage: "timer")
                }
                Spacer()
                if !task.result.isEmpty {
                    Button(expanded.contains(task.id) ? "Less" : "Result") {
                        toggleExpanded(task.id)
                    }
                    .buttonStyle(.plain)
                    .font(.nCaption)
                    .foregroundStyle(Color.nAccent)
                    Button("Copy") {
                        model.copyToClipboard(task.result)
                    }
                    .buttonStyle(.plain)
                    .font(.nCaption)
                    .foregroundStyle(Color.nTextSecondary)
                }
                if let conversationID = task.conversationID,
                   model.conversation(id: conversationID) != nil {
                    Button("Open Chat") {
                        model.selectConversation(conversationID)
                    }
                    .buttonStyle(.plain)
                    .font(.nCaption)
                    .foregroundStyle(Color.nAccent)
                }
            }
            .font(.nCaptionRegular)
            .foregroundStyle(Color.nTextTertiary)
        }
        .padding(9)
        .padding(.vertical, 2)
    }

    private func toggleExpanded(_ id: UUID) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }

    private func statusColor(_ status: AITaskStatus) -> Color {
        switch status {
        case .pending: .nTextTertiary
        case .running: .nAccent
        case .completed: .nSuccess
        case .failed: .nDanger
        case .cancelled: .nWarning
        }
    }

    private func kindSymbol(_ kind: AITaskKind) -> String {
        switch kind {
        case .chat: "bubble.left"
        case .multiAI: "square.split.2x2"
        case .compare: "arrow.left.arrow.right"
        case .handoffSummary: "doc.text"
        case .workflow: "point.3.connected.trianglepath.dotted"
        case .voice: "waveform"
        }
    }
}

struct TaskStatusPill: View {
    let status: AITaskStatus

    var body: some View {
        HStack(spacing: 4) {
            if status == .running || status == .pending {
                Spinner()
                    .scaleEffect(0.7)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            }
            Text(label)
                .font(.nCaption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.08)))
        .overlay {
            Capsule().strokeBorder(color.opacity(0.14), lineWidth: 0.6)
        }
    }

    private var label: String {
        switch status {
        case .pending: "Pending"
        case .running: "Running"
        case .completed: "Complete"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    private var color: Color {
        switch status {
        case .pending: .nTextTertiary
        case .running: .nAccent
        case .completed: .nSuccess
        case .failed: .nDanger
        case .cancelled: .nWarning
        }
    }
}

struct IndeterminateProgressBar: View {
    var tint: Color = .nAccent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.black)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, tint.opacity(0.75), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * 0.38)
                        .offset(x: animate ? proxy.size.width : -proxy.size.width * 0.38)
                }
                .clipShape(Capsule())
        }
        .frame(height: 2.5)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
        .accessibilityLabel("In progress")
    }
}
