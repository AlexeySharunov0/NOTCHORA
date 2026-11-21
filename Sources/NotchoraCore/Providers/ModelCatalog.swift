import Foundation
import Observation

/// Model lists are supplied by providers at runtime. Curated defaults keep the
/// app usable before the first refresh; custom IDs let users address new models
/// without waiting for an app update.
@MainActor
@Observable
public final class ModelCatalog {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var discovered: [AIProviderID: [AIModel]]
    @ObservationIgnored private var custom: [AIProviderID: [AIModel]]

    public private(set) var lastRefresh: [AIProviderID: Date] = [:]
    public private(set) var refreshErrors: [AIProviderID: String] = [:]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.discovered = Self.loadModels(from: defaults, key: Keys.discovered)
        self.custom = Self.loadModels(from: defaults, key: Keys.custom)
    }

    public func models(for provider: AIProviderID) -> [AIModel] {
        var byID: [String: AIModel] = [:]
        let base = (discovered[provider]?.isEmpty == false)
            ? (discovered[provider] ?? [])
            : ModelCatalogDefaults.models(for: provider)
        for model in base { byID[model.id] = model }
        for model in custom[provider] ?? [] { byID[model.id] = model }
        return byID.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    public func customModels(for provider: AIProviderID) -> [AIModel] {
        (custom[provider] ?? []).sorted { $0.id < $1.id }
    }

    public func model(for selection: ModelSelection) -> AIModel {
        if let match = models(for: selection.providerID).first(where: { $0.id == selection.modelID }) {
            return match
        }
        if let builtIn = ModelCatalogDefaults.models(for: selection.providerID).first(where: { $0.id == selection.modelID }) {
            return builtIn
        }
        return AIModel(
            id: selection.modelID,
            providerID: selection.providerID,
            displayName: ModelHeuristics.displayName(for: selection.modelID, provider: selection.providerID),
            supportsVision: ModelHeuristics.supportsVision(id: selection.modelID, provider: selection.providerID),
            source: .custom
        )
    }

    public func hasUsableModel(for provider: AIProviderID) -> Bool {
        !models(for: provider).isEmpty
    }

    public func refresh(provider: AIProviderID, using service: any AIServicing) async throws {
        do {
            let fetched = try await service.listModels(for: provider)
            guard !fetched.isEmpty else { throw AIProviderError.noAvailableModel }
            discovered[provider] = fetched
            refreshErrors[provider] = nil
            lastRefresh[provider] = Date()
            persistModels(discovered, key: Keys.discovered)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            refreshErrors[provider] = message
            throw error
        }
    }

    /// Called by Settings after credentials have already been validated.
    public func installDiscovered(_ models: [AIModel], for provider: AIProviderID) {
        guard !models.isEmpty else { return }
        discovered[provider] = models
        refreshErrors[provider] = nil
        lastRefresh[provider] = Date()
        persistModels(discovered, key: Keys.discovered)
    }

    public func addCustomModel(id rawID: String, provider: AIProviderID) throws {
        let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id.count <= 160 else {
            throw AIProviderError.unsupportedContent("Enter a valid model identifier.")
        }
        guard !models(for: provider).contains(where: { $0.id == id }) else {
            throw AIProviderError.unsupportedContent("That model is already in the list.")
        }
        var list = custom[provider] ?? []
        list.append(AIModel(
            id: id,
            providerID: provider,
            displayName: ModelHeuristics.displayName(for: id, provider: provider),
            supportsVision: ModelHeuristics.supportsVision(id: id, provider: provider),
            source: .custom
        ))
        custom[provider] = list
        persistModels(custom, key: Keys.custom)
    }

    public func removeCustomModel(id: String, provider: AIProviderID) {
        custom[provider]?.removeAll { $0.id == id }
        persistModels(custom, key: Keys.custom)
    }

    public func clearRefreshError(for provider: AIProviderID) {
        refreshErrors[provider] = nil
    }


    private func persistModels(_ map: [AIProviderID: [AIModel]], key: String) {
        let stringKeyed = Dictionary(uniqueKeysWithValues: map.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(stringKeyed) {
            defaults.set(data, forKey: key)
        }
    }

    private static func loadModels(from defaults: UserDefaults, key: String) -> [AIProviderID: [AIModel]] {
        guard let data = defaults.data(forKey: key),
              let stringKeyed = try? JSONDecoder().decode([String: [AIModel]].self, from: data) else {
            return [:]
        }
        var result: [AIProviderID: [AIModel]] = [:]
        for (raw, models) in stringKeyed {
            if let provider = AIProviderID(rawValue: raw) {
                result[provider] = models
            }
        }
        return result
    }

    private enum Keys {
        static let discovered = "notchora.models.discovered"
        static let custom = "notchora.models.custom"
    }
}
