import Foundation
import XCTest
@testable import NotchoraCore

final class StorageTests: XCTestCase {
    func testStateRoundTripPreservesConversationsTasksAndWorkflows() async throws {
        let directory = TestFixtures.temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("state.json")
        let store = StateStore(fileURL: fileURL)

        var conversation = TestFixtures.conversation()
        conversation.isPinned = true
        let task = AITask(
            title: "Test task",
            kind: .chat,
            providerID: .openAI,
            modelID: "gpt-4.1",
            status: .completed,
            result: "Task result"
        )
        let workflow = WorkflowPresets.standard()[0]
        let state = PersistedState(
            conversations: [conversation],
            tasks: [task],
            workflows: [workflow],
            launcherEntries: [LauncherEntry(name: "ChatGPT", bundleIdentifier: "com.openai.chat")],
            lastConversationID: conversation.id
        )

        try await store.save(state)
        let loaded = try await store.load()
        let unwrapped = try XCTUnwrap(loaded)
        XCTAssertEqual(unwrapped.conversations.first?.id, conversation.id)
        XCTAssertEqual(unwrapped.conversations.first?.messages.count, conversation.messages.count)
        XCTAssertEqual(unwrapped.conversations.first?.isPinned, true)
        XCTAssertEqual(unwrapped.tasks.first?.id, task.id)
        XCTAssertEqual(unwrapped.tasks.first?.status, .completed)
        XCTAssertEqual(unwrapped.workflows.first?.id, workflow.id)
        XCTAssertEqual(unwrapped.launcherEntries.first?.name, "ChatGPT")
        XCTAssertEqual(unwrapped.lastConversationID, conversation.id)

        let permissions = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
    }

    func testCorruptStateIsQuarantined() async throws {
        let directory = TestFixtures.temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("state.json")
        try Data("this is not json".utf8).write(to: fileURL)
        let store = StateStore(fileURL: fileURL)

        do {
            _ = try await store.load()
            XCTFail("Expected corrupted state error")
        } catch let error as StateStoreError {
            guard case .corruptedState = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertFalse(files.contains("state.json"))
        XCTAssertTrue(files.contains { $0.hasPrefix("state.corrupt-") })
    }

    func testUnsupportedFutureSchemaFails() async throws {
        let directory = TestFixtures.temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("state.json")
        let store = StateStore(fileURL: fileURL)
        let future = PersistedState(schemaVersion: 999)
        try await store.save(future)

        do {
            _ = try await store.load()
            XCTFail("Expected unsupported schema")
        } catch let error as StateStoreError {
            guard case .unsupportedSchema = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testInMemoryKeychainStoreBehavior() throws {
        let store = InMemoryKeychainStore()
        let provider = AIProviderID.anthropic
        XCTAssertFalse(store.hasKey(for: provider))
        XCTAssertNil(try store.load(for: provider))

        try store.save("  sk-ant-secret  ", for: provider)
        XCTAssertTrue(store.hasKey(for: provider))
        XCTAssertEqual(try store.load(for: provider), "sk-ant-secret")

        try store.save("replacement", for: provider)
        XCTAssertEqual(try store.load(for: provider), "replacement")

        try store.delete(for: provider)
        XCTAssertFalse(store.hasKey(for: provider))
        XCTAssertNoThrow(try store.delete(for: provider))
    }

    func testAPIKeyIsNotWrittenIntoStateFile() async throws {
        let directory = TestFixtures.temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("state.json")
        let store = StateStore(fileURL: fileURL)
        try await store.save(PersistedState(conversations: [TestFixtures.conversation()]))

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(contents.contains("sk-"))
        XCTAssertFalse(contents.contains("apiKey"))
    }
}
