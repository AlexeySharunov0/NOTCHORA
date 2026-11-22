import Foundation
import Security

public enum KeychainError: Error, LocalizedError, Sendable {
    case unexpectedStatus(OSStatus)
    case dataCorrupted

    public var errorDescription: String? {
        switch self {
        case let .unexpectedStatus(status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return "Keychain error: \(message)."
            }
            return "Keychain error \(status)."
        case .dataCorrupted:
            return "The stored credential could not be read."
        }
    }
}

public protocol APIKeyStore: Sendable {
    func save(_ key: String, for provider: AIProviderID) throws
    func load(for provider: AIProviderID) throws -> String?
    func delete(for provider: AIProviderID) throws
    func hasKey(for provider: AIProviderID) -> Bool
}

/// The only place API keys are persisted. The service name is stable so keys
/// survive app updates; accounts are one per provider.
public struct SystemKeychainStore: APIKeyStore, Sendable {
    public let service: String
    public let accessGroup: String?

    public init(service: String = "com.notchora.credentials", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func save(_ key: String, for provider: AIProviderID) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw KeychainError.dataCorrupted }
        let data = Data(trimmed.utf8)
        var query = baseQuery(provider)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updateQuery = baseQuery(provider)
            let attributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func load(for provider: AIProviderID) throws -> String? {
        var query = baseQuery(provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.dataCorrupted
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func delete(for provider: AIProviderID) throws {
        let status = SecItemDelete(baseQuery(provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func hasKey(for provider: AIProviderID) -> Bool {
        var query = baseQuery(provider)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    private func baseQuery(_ provider: AIProviderID) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}

/// Deterministic store for tests. Never used by the shipping app.
public final class InMemoryKeychainStore: APIKeyStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [AIProviderID: String] = [:]

    public init(values: [AIProviderID: String] = [:]) {
        self.values = values
    }

    public func save(_ key: String, for provider: AIProviderID) throws {
        lock.lock()
        defer { lock.unlock() }
        values[provider] = key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func load(for provider: AIProviderID) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[provider]
    }

    public func delete(for provider: AIProviderID) throws {
        lock.lock()
        defer { lock.unlock() }
        values[provider] = nil
    }

    public func hasKey(for provider: AIProviderID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return values[provider] != nil
    }
}
