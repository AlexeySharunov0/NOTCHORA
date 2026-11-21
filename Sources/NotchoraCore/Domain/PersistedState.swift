import Foundation

public struct PersistedState: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var conversations: [Conversation]
    public var tasks: [AITask]
    public var workflows: [Workflow]
    public var launcherEntries: [LauncherEntry]
    public var lastConversationID: UUID?
    public var savedAt: Date

    public init(
        schemaVersion: Int = PersistedState.currentSchemaVersion,
        conversations: [Conversation] = [],
        tasks: [AITask] = [],
        workflows: [Workflow] = [],
        launcherEntries: [LauncherEntry] = [],
        lastConversationID: UUID? = nil,
        savedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.conversations = conversations
        self.tasks = tasks
        self.workflows = workflows
        self.launcherEntries = launcherEntries
        self.lastConversationID = lastConversationID
        self.savedAt = savedAt
    }

    public static func fresh() -> PersistedState {
        PersistedState(
            conversations: [],
            workflows: WorkflowPresets.standard(),
            launcherEntries: LauncherEntry.suggested
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, conversations, tasks, workflows, launcherEntries, lastConversationID, savedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        conversations = try container.decodeIfPresent([Conversation].self, forKey: .conversations) ?? []
        tasks = try container.decodeIfPresent([AITask].self, forKey: .tasks) ?? []
        workflows = try container.decodeIfPresent([Workflow].self, forKey: .workflows) ?? []
        launcherEntries = try container.decodeIfPresent([LauncherEntry].self, forKey: .launcherEntries) ?? []
        lastConversationID = try container.decodeIfPresent(UUID.self, forKey: .lastConversationID)
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
    }
}
