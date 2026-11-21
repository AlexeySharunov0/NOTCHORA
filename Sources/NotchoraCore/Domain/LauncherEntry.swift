import Foundation

public struct LauncherEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var bundleIdentifier: String?
    public var applicationPath: String?
    public var customURL: String?
    public var createdAt: Date
    public var isSuggested: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String? = nil,
        applicationPath: String? = nil,
        customURL: String? = nil,
        createdAt: Date = Date(),
        isSuggested: Bool = true
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.applicationPath = applicationPath
        self.customURL = customURL
        self.createdAt = createdAt
        self.isSuggested = isSuggested
    }

    public static let suggested: [LauncherEntry] = [
        LauncherEntry(name: "ChatGPT", bundleIdentifier: "com.openai.chat"),
        LauncherEntry(name: "Claude", bundleIdentifier: "com.anthropic.claudefordesktop"),
        LauncherEntry(name: "Cursor", bundleIdentifier: "com.todesktop.230313mzl4w4u92"),
        LauncherEntry(name: "Perplexity", bundleIdentifier: "ai.perplexity.mac"),
        LauncherEntry(name: "Warp", bundleIdentifier: "dev.warp.Warp-Stable")
    ]
}
