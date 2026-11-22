import Foundation
import NotchoraCore

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let model: AppModel

    private init() {
        #if DEBUG
        let isQA = ProcessInfo.processInfo.environment["NOTCHORA_QA"] == "1"
        let defaults = isQA
            ? (UserDefaults(suiteName: "com.notchora.app.qa") ?? .standard)
            : UserDefaults.standard
        let keyStore: any APIKeyStore = isQA
            ? InMemoryKeychainStore()
            : SystemKeychainStore(service: "com.notchora.app.credentials")
        #else
        let defaults = UserDefaults.standard
        let keyStore: any APIKeyStore = SystemKeychainStore(service: "com.notchora.app.credentials")
        #endif

        let settings = SettingsStore(defaults: defaults)

        let registry = ProviderRegistry()
        let service = AIService(registry: registry, keyStore: keyStore)
        let catalog = ModelCatalog(defaults: defaults)
        let stateURL: URL
        if let override = ProcessInfo.processInfo.environment["NOTCHORA_STATE_PATH"],
           !override.isEmpty {
            stateURL = URL(fileURLWithPath: override)
        } else {
            stateURL = StateStore.defaultFileURL()
        }
        let store = StateStore(fileURL: stateURL)
        model = AppModel(
            settings: settings,
            keyStore: keyStore,
            service: service,
            stateStore: store,
            catalog: catalog
        )
    }
}
