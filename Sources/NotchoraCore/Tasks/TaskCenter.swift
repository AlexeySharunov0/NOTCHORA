import Foundation
import Observation

/// Owns the observable task list and the cancellation handles for work that is
/// currently in flight. Persistence is coordinated by the app model so a task
/// and its conversation are saved in the same snapshot.
@MainActor
@Observable
public final class TaskCenter {
    public private(set) var tasks: [AITask]

    @ObservationIgnored
    private var handles: [UUID: Task<Void, Never>] = [:]

    public init(tasks: [AITask] = []) {
        self.tasks = TaskRecovery.recover(tasks)
    }

    public func replace(with tasks: [AITask]) {
        for handle in handles.values { handle.cancel() }
        handles.removeAll()
        self.tasks = TaskRecovery.recover(tasks)
    }

    public func reset() {
        for handle in handles.values { handle.cancel() }
        handles.removeAll()
        tasks.removeAll()
    }

    public var runningCount: Int {
        tasks.filter { $0.status == .running || $0.status == .pending }.count
    }

    public var hasRunningTasks: Bool { runningCount > 0 }

    public var sortedTasks: [AITask] {
        tasks.sorted {
            if $0.status.isTerminal != $1.status.isTerminal { return !$0.status.isTerminal }
            return $0.createdAt > $1.createdAt
        }
    }

    @discardableResult
    public func create(
        title: String,
        kind: AITaskKind,
        providerID: AIProviderID,
        modelID: String,
        conversationID: UUID? = nil,
        workflowID: UUID? = nil,
        workflowRunID: UUID? = nil
    ) -> UUID {
        let task = AITask(
            title: title,
            kind: kind,
            providerID: providerID,
            modelID: modelID,
            status: .pending,
            conversationID: conversationID,
            workflowID: workflowID,
            workflowRunID: workflowRunID
        )
        tasks.insert(task, at: 0)
        return task.id
    }

    public func bind(_ handle: Task<Void, Never>, to id: UUID) {
        handles[id] = handle
    }

    public func markRunning(_ id: UUID) {
        update(id) { task in
            task.status = .running
            task.startedAt = task.startedAt ?? Date()
        }
    }

    public func appendResult(_ text: String, to id: UUID) {
        update(id) { $0.result = text }
    }

    public func complete(_ id: UUID, result: String) {
        handles[id] = nil
        update(id) { task in
            task.status = .completed
            task.result = result
            task.finishedAt = Date()
        }
    }

    public func fail(_ id: UUID, error: String) {
        handles[id] = nil
        update(id) { task in
            task.status = .failed
            task.errorDescription = error
            task.finishedAt = Date()
        }
    }

    public func cancel(_ id: UUID) {
        handles[id]?.cancel()
        handles[id] = nil
        update(id) { task in
            guard !task.status.isTerminal else { return }
            task.status = .cancelled
            task.finishedAt = Date()
        }
    }

    public func cancelAll() {
        let ids = Array(handles.keys)
        for id in ids { cancel(id) }
    }

    public func remove(_ id: UUID) {
        handles[id]?.cancel()
        handles[id] = nil
        tasks.removeAll { $0.id == id }
    }

    public func clearFinished() {
        tasks.removeAll { $0.status.isTerminal }
    }

    public func task(_ id: UUID) -> AITask? {
        tasks.first { $0.id == id }
    }

    public func isRunning(_ id: UUID) -> Bool {
        guard let task = task(id) else { return false }
        return task.status == .running || task.status == .pending
    }

    private func update(_ id: UUID, _ mutate: (inout AITask) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        mutate(&tasks[index])
    }
}
