import Foundation

public enum AITaskStatus: String, Codable, Hashable, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: true
        case .pending, .running: false
        }
    }
}

public enum AITaskKind: String, Codable, Hashable, Sendable {
    case chat
    case multiAI
    case compare
    case handoffSummary
    case workflow
    case voice
}

public struct AITask: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var kind: AITaskKind
    public var providerID: AIProviderID
    public var modelID: String
    public var createdAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?
    public var status: AITaskStatus
    public var result: String
    public var errorDescription: String?
    public var conversationID: UUID?
    public var workflowID: UUID?
    public var workflowRunID: UUID?

    public init(
        id: UUID = UUID(),
        title: String,
        kind: AITaskKind,
        providerID: AIProviderID,
        modelID: String,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        status: AITaskStatus = .pending,
        result: String = "",
        errorDescription: String? = nil,
        conversationID: UUID? = nil,
        workflowID: UUID? = nil,
        workflowRunID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.providerID = providerID
        self.modelID = modelID
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.status = status
        self.result = result
        self.errorDescription = errorDescription
        self.conversationID = conversationID
        self.workflowID = workflowID
        self.workflowRunID = workflowRunID
    }

    public var duration: TimeInterval? {
        guard let startedAt else { return nil }
        return (finishedAt ?? Date()).timeIntervalSince(startedAt)
    }
}

/// Restored tasks must never appear to still be running after a relaunch:
/// the in-process work is gone even if the provider produced output before.
public enum TaskRecovery {
    public static func recover(_ tasks: [AITask]) -> [AITask] {
        tasks.map { task in
            var copy = task
            if task.status == .pending || task.status == .running {
                copy.status = .cancelled
                copy.finishedAt = task.finishedAt ?? Date()
                copy.errorDescription = "Interrupted when NOTCHORA quit. Partial output was kept when available."
            }
            return copy
        }
    }
}
