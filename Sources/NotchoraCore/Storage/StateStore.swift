import Foundation
import OSLog

public enum StateStoreError: Error, LocalizedError, Sendable {
    case unsupportedSchema(Int)
    case corruptedState(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version):
            "This history was written by a newer version of NOTCHORA (schema \(version))."
        case let .corruptedState(message):
            "NOTCHORA could not read its local state: \(message)"
        }
    }
}

/// Atomic JSON persistence for chats, tasks, workflows and launcher entries.
/// The store is intentionally serialized behind an actor; the UI never waits
/// for disk I/O on the main thread.
public actor StateStore {
    public let fileURL: URL
    public let directoryURL: URL

    private let logger = Logger(subsystem: "com.notchora.app", category: "StateStore")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.directoryURL = fileURL.deletingLastPathComponent()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public static func defaultFileURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return support
            .appendingPathComponent("NOTCHORA", isDirectory: true)
            .appendingPathComponent("state.json", isDirectory: false)
    }

    public func load() throws -> PersistedState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let state = try decoder.decode(PersistedState.self, from: data)
            guard state.schemaVersion <= PersistedState.currentSchemaVersion else {
                throw StateStoreError.unsupportedSchema(state.schemaVersion)
            }
            return state
        } catch let error as StateStoreError {
            throw error
        } catch {
            logger.error("State decode failed: \(String(describing: error), privacy: .public)")
            quarantineCorruptFile()
            throw StateStoreError.corruptedState(error.localizedDescription)
        }
    }

    public func save(_ state: PersistedState) throws {
        try ensureDirectory()
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    public func deleteAll() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func quarantineCorruptFile() {
        let backup = directoryURL.appendingPathComponent("state.corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: fileURL, to: backup)
        logger.error("Quarantined unreadable state file at \(backup.lastPathComponent, privacy: .public)")
    }
}
