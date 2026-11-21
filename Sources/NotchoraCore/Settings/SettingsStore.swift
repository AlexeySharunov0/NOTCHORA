import Foundation
import Observation

/// User preferences persisted in UserDefaults. Secrets never live here; API
/// keys are handled exclusively by `KeychainStore`.
@MainActor
@Observable
public final class SettingsStore {
    @ObservationIgnored
    private let defaults: UserDefaults

    public var appearance: AppAppearance { didSet { persist(appearance.rawValue, Key.appearance) } }
    public var animationsEnabled: Bool { didSet { persist(animationsEnabled, Key.animations) } }
    public var transparencyEnabled: Bool { didSet { persist(transparencyEnabled, Key.transparency) } }
    public var density: InterfaceDensity { didSet { persist(density.rawValue, Key.density) } }
    public var launchAtLogin: Bool { didSet { persist(launchAtLogin, Key.launchAtLogin) } }
    public var defaultBehavior: DefaultBehavior { didSet { persist(defaultBehavior.rawValue, Key.defaultBehavior) } }
    public var defaultProviderID: AIProviderID { didSet { persist(defaultProviderID.rawValue, Key.defaultProvider) } }
    public var defaultModelID: String { didSet { persist(defaultModelID, Key.defaultModel) } }
    public var defaultSystemPrompt: String { didSet { persist(defaultSystemPrompt, Key.systemPrompt) } }
    public var temperature: Double { didSet { persist(temperature, Key.temperature) } }
    public var maxOutputTokens: Int { didSet { persist(maxOutputTokens, Key.maxOutputTokens) } }
    public var voiceAutoSpeak: Bool { didSet { persist(voiceAutoSpeak, Key.voiceAutoSpeak) } }
    public var voiceLocaleIdentifier: String { didSet { persist(voiceLocaleIdentifier, Key.voiceLocale) } }
    public var speechRate: Double { didSet { persist(speechRate, Key.speechRate) } }
    public var historyEnabled: Bool { didSet { persist(historyEnabled, Key.historyEnabled) } }
    public var maxStoredConversations: Int { didSet { persist(maxStoredConversations, Key.historyLimit) } }
    public var showMenuBarItem: Bool { didSet { persist(showMenuBarItem, Key.menuBarItem) } }
    public var displayPreference: DisplayPreference { didSet { persist(displayPreference.rawValue, Key.displayPreference) } }
    public var hoverToExpand: Bool { didSet { persist(hoverToExpand, Key.hoverToExpand) } }
    public var hasCompletedOnboarding: Bool { didSet { persist(hasCompletedOnboarding, Key.onboarding) } }
    public var shortcuts: [ShortcutBinding] { didSet { persistShortcuts() } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedAppearance = defaults.string(forKey: Key.appearance)
        appearance = AppAppearance(rawValue: storedAppearance ?? "") ?? .system
        animationsEnabled = defaults.object(forKey: Key.animations) as? Bool ?? true
        transparencyEnabled = defaults.object(forKey: Key.transparency) as? Bool ?? true
        density = InterfaceDensity(rawValue: defaults.string(forKey: Key.density) ?? "") ?? .comfortable
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        defaultBehavior = DefaultBehavior(rawValue: defaults.string(forKey: Key.defaultBehavior) ?? "") ?? .lastConversation
        let providerRaw = defaults.string(forKey: Key.defaultProvider) ?? ""
        let provider = AIProviderID(rawValue: providerRaw) ?? .openAI
        defaultProviderID = provider
        defaultModelID = defaults.string(forKey: Key.defaultModel) ?? provider.defaultModelID
        defaultSystemPrompt = defaults.string(forKey: Key.systemPrompt) ?? ""
        temperature = defaults.object(forKey: Key.temperature) as? Double ?? 0.7
        maxOutputTokens = defaults.object(forKey: Key.maxOutputTokens) as? Int ?? 0
        voiceAutoSpeak = defaults.object(forKey: Key.voiceAutoSpeak) as? Bool ?? true
        voiceLocaleIdentifier = defaults.string(forKey: Key.voiceLocale) ?? ""
        speechRate = defaults.object(forKey: Key.speechRate) as? Double ?? 0.5
        historyEnabled = defaults.object(forKey: Key.historyEnabled) as? Bool ?? true
        maxStoredConversations = defaults.object(forKey: Key.historyLimit) as? Int ?? 200
        showMenuBarItem = defaults.object(forKey: Key.menuBarItem) as? Bool ?? true
        displayPreference = DisplayPreference(rawValue: defaults.string(forKey: Key.displayPreference) ?? "") ?? .activeScreen
        hoverToExpand = defaults.object(forKey: Key.hoverToExpand) as? Bool ?? false
        hasCompletedOnboarding = defaults.bool(forKey: Key.onboarding)

        if let data = defaults.data(forKey: Key.shortcuts),
           let decoded = try? JSONDecoder().decode([ShortcutBinding].self, from: data),
           Set(decoded.map(\.action)) == Set(ShortcutAction.allCases) {
            shortcuts = decoded
        } else {
            shortcuts = ShortcutBinding.defaults
        }
    }

    public var effectiveModelSelection: ModelSelection {
        ModelSelection(providerID: defaultProviderID, modelID: defaultModelID)
    }

    public var maxOutputTokensValue: Int? {
        maxOutputTokens > 0 ? maxOutputTokens : nil
    }

    public func binding(for action: ShortcutAction) -> ShortcutBinding? {
        shortcuts.first { $0.action == action }
    }

    public func updateShortcut(_ binding: ShortcutBinding) {
        guard let index = shortcuts.firstIndex(where: { $0.action == binding.action }) else {
            shortcuts.append(binding)
            return
        }
        shortcuts[index] = binding
    }

    public func duplicateShortcut(for action: ShortcutAction, combo: KeyCombo) -> ShortcutAction? {
        shortcuts.first { $0.action != action && $0.isEnabled && $0.combo == combo }?.action
    }

    public func resetShortcuts() {
        shortcuts = ShortcutBinding.defaults
    }

    public func resetGeneralSettings() {
        appearance = .system
        animationsEnabled = true
        transparencyEnabled = true
        density = .comfortable
        defaultBehavior = .lastConversation
        defaultProviderID = .openAI
        defaultModelID = AIProviderID.openAI.defaultModelID
        defaultSystemPrompt = ""
        temperature = 0.7
        maxOutputTokens = 0
        displayPreference = .activeScreen
        hoverToExpand = false
    }

    public func resetPrivacySettings() {
        historyEnabled = true
        maxStoredConversations = 200
        voiceAutoSpeak = true
    }

    private func persist<T>(_ value: T, _ key: String) {
        defaults.set(value, forKey: key)
    }

    private func persistShortcuts() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            defaults.set(data, forKey: Key.shortcuts)
        }
    }

    private enum Key {
        static let appearance = "notchora.appearance"
        static let animations = "notchora.animations"
        static let transparency = "notchora.transparency"
        static let density = "notchora.density"
        static let launchAtLogin = "notchora.launchAtLogin"
        static let defaultBehavior = "notchora.defaultBehavior"
        static let defaultProvider = "notchora.defaultProvider"
        static let defaultModel = "notchora.defaultModel"
        static let systemPrompt = "notchora.systemPrompt"
        static let temperature = "notchora.temperature"
        static let maxOutputTokens = "notchora.maxOutputTokens"
        static let voiceAutoSpeak = "notchora.voiceAutoSpeak"
        static let voiceLocale = "notchora.voiceLocale"
        static let speechRate = "notchora.speechRate"
        static let historyEnabled = "notchora.historyEnabled"
        static let historyLimit = "notchora.historyLimit"
        static let menuBarItem = "notchora.menuBarItem"
        static let displayPreference = "notchora.displayPreference"
        static let hoverToExpand = "notchora.hoverToExpand"
        static let onboarding = "notchora.onboarding"
        static let shortcuts = "notchora.shortcuts"
    }
}
