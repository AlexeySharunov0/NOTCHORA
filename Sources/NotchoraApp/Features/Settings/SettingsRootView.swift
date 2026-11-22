import AppKit
import NotchoraCore
import SwiftUI

struct SettingsRootView: View {
    let model: AppModel
    var embedded: Bool = true

    @State private var selection: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 194)

            Rectangle()
                .fill(Color.nHairline)
                .frame(width: 0.8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    pageHeader
                    pageContent
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 30)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.black)
        .tint(Color.nAccent)
        .preferredColorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: applyRequestedTab)
        .onChange(of: model.settingsTabRequest) { _, _ in applyRequestedTab() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            if embedded {
                HStack(spacing: 7) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.nTextSecondary)
                    Text("SETTINGS")
                        .font(.system(size: 8.5, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(Color.nTextSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 14)
            } else {
                HStack(spacing: 8) {
                    NotchoraMark(size: 28)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("NOTCHORA")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(Color.nTextPrimary)
                        Text("SETTINGS")
                            .font(.system(size: 7.5, weight: .medium))
                            .tracking(1.0)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 16)
            }

            VStack(spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selection = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.symbolName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(selection == tab ? Color.nAccent : Color.nTextSecondary)
                                .frame(width: 17)
                            Text(tab.title)
                                .font(.nSmall)
                                .foregroundStyle(selection == tab ? Color.nTextPrimary : Color.nTextSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight(radius: 7)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            VStack(alignment: .leading, spacing: 3) {
                Text("NOTCHORA \(appVersion)")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                Text("Your AI. One notch away.")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.black)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(selection.title)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color.nTextPrimary)
            Text(pageSubtitle)
                .font(.nSmall)
                .foregroundStyle(Color.nTextSecondary)
        }
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selection {
        case .general:
            GeneralSettingsView(model: model)
        case .providers:
            ProvidersSettingsView(model: model)
        case .shortcuts:
            ShortcutsSettingsView(model: model)
        case .appearance:
            AppearanceSettingsView(model: model)
        case .privacy:
            PrivacySettingsView(model: model)
        case .about:
            AboutSettingsView(model: model)
        }
    }

    private var pageSubtitle: String {
        switch selection {
        case .general: "Startup, defaults, and how the notch behaves."
        case .providers: "Connect models. Credentials never leave the macOS Keychain."
        case .shortcuts: "Global key combinations. They can be changed at any time."
        case .appearance: "Theme, materials, density, and motion."
        case .privacy: "Permissions, local data, and what is sent to AI providers."
        case .about: "A native AI control center for macOS."
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return version
    }

    private func applyRequestedTab() {
        if let requested = model.settingsTabRequest {
            selection = requested
            model.settingsTabRequest = nil
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content

    init(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            VStack(spacing: 0) {
                content
            }
            .background(Color.black)
            if let footer {
                Text(footer)
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(minHeight: 38)
    }
}

private struct GeneralSettingsView: View {
    let model: AppModel

    var body: some View {
        @Bindable var settings = model.settings

        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Startup") {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Launch at login")
                            .font(.nSmall)
                        Text(LaunchAtLoginService.statusDescription)
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
                Divider().padding(.leading, 12)
                SettingsRow {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Show menu bar item")
                            .font(.nSmall)
                        Text("The notch remains available when this is off.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.showMenuBarItem)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: settings.showMenuBarItem) { _, _ in
                            model.applyMenuBarVisibility()
                        }
                }
            }

            SettingsSection(title: "Behavior") {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Default action")
                            .font(.nSmall)
                        Text("What opens when you invoke the panel.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    Spacer()
                    Menu {
                        ForEach(DefaultBehavior.allCases, id: \.self) { behavior in
                            Button {
                                settings.defaultBehavior = behavior
                            } label: {
                                if settings.defaultBehavior == behavior {
                                    Label(behavior.displayName, systemImage: "checkmark")
                                } else {
                                    Text(behavior.displayName)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(settings.defaultBehavior.displayName)
                                .font(.nSmall)
                                .foregroundStyle(Color.nTextSecondary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(Color.nTextTertiary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
                Divider().padding(.leading, 12)
                SettingsRow {
                    Text("Default provider")
                        .font(.nSmall)
                    Spacer()
                    Menu {
                        ForEach(AIProviderID.allCases) { provider in
                            Button {
                                settings.defaultProviderID = provider
                                settings.defaultModelID = model.catalog.models(for: provider).first?.id
                                    ?? provider.defaultModelID
                            } label: {
                                if settings.defaultProviderID == provider {
                                    Label(provider.displayName, systemImage: "checkmark")
                                } else {
                                    Text(provider.displayName)
                                }
                            }
                        }
                    } label: {
                        Text(settings.defaultProviderID.displayName)
                            .font(.nSmall)
                            .foregroundStyle(Color.nTextSecondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                Divider().padding(.leading, 12)
                SettingsRow {
                    Text("Default model")
                        .font(.nSmall)
                    Spacer()
                    Menu {
                        ForEach(model.catalog.models(for: settings.defaultProviderID)) { candidate in
                            Button {
                                settings.defaultModelID = candidate.id
                            } label: {
                                if settings.defaultModelID == candidate.id {
                                    Label(candidate.displayName, systemImage: "checkmark")
                                } else {
                                    Text(candidate.displayName)
                                }
                            }
                        }
                    } label: {
                        Text(model.catalog.model(for: ModelSelection(
                            providerID: settings.defaultProviderID,
                            modelID: settings.defaultModelID
                        )).displayName)
                            .font(.nSmall)
                            .foregroundStyle(Color.nTextSecondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            SettingsSection(title: "Notch", footer: "Hover expansion expands the panel after a short delay. Disable it if you prefer click-only activation.") {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Expand on hover")
                            .font(.nSmall)
                        Text("Clicking the notch always works.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.hoverToExpand)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                Divider().padding(.leading, 12)
                SettingsRow {
                    Text("Show panel on")
                        .font(.nSmall)
                    Spacer()
                    Menu {
                        ForEach(DisplayPreference.allCases, id: \.self) { preference in
                            Button {
                                settings.displayPreference = preference
                            } label: {
                                if settings.displayPreference == preference {
                                    Label(preference.displayName, systemImage: "checkmark")
                                } else {
                                    Text(preference.displayName)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(settings.displayPreference.displayName)
                                .font(.nSmall)
                                .foregroundStyle(Color.nTextSecondary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(Color.nTextTertiary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }

            HStack {
                Spacer()
                Button("Reset General Settings") {
                    settings.resetGeneralSettings()
                }
                .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
            }
        }
    }
}

private struct ProvidersSettingsView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.nSuccess)
                Text("Keys are stored in the macOS Keychain. They are never written to settings, history, or logs.")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
            .padding(.bottom, 2)

            ForEach(AIProviderID.allCases) { provider in
                ProviderSettingsCard(model: model, provider: provider)
            }
        }
    }
}

private struct ProviderSettingsCard: View {
    let model: AppModel
    let provider: AIProviderID

    @State private var draftKey = ""
    @State private var customModelID = ""
    @State private var message: String?
    @State private var messageIsError = false
    @State private var deleteKeyPresented = false
    @State private var showAdvanced = false

    private var inProgress: Bool { model.providerActionInProgress == provider }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                ProviderGlyph(provider: provider, size: 27)
                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.displayName)
                        .font(.nHeadline)
                        .foregroundStyle(Color.nTextPrimary)
                    Text(model.hasAPIKey(provider) ? "API key stored in Keychain" : "Not connected")
                        .font(.nCaptionRegular)
                        .foregroundStyle(model.hasAPIKey(provider) ? Color.nSuccess : Color.nTextTertiary)
                }
                Spacer()
                if inProgress {
                    Spinner()
                }
                Badge(text: model.hasAPIKey(provider) ? "Connected" : "No key",
                      color: model.hasAPIKey(provider) ? .nSuccess : .nTextTertiary)
            }

            HStack(spacing: 7) {
                SecureField("Paste a new \(provider.displayName) API key", text: $draftKey)
                    .textFieldStyle(NotchTextFieldStyle())
                    .font(.system(size: 11.5, design: .monospaced))
                Button("Save & Verify") {
                    save(verify: true)
                }
                .buttonStyle(NButtonStyle(variant: .primary, compact: true))
                .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || inProgress)
                Button("Save") {
                    save(verify: false)
                }
                .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
                .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || inProgress)
            }

            HStack(spacing: 7) {
                if model.hasAPIKey(provider) {
                    Button("Test Connection") {
                        Task { await model.testProviderConnection(provider) }
                    }
                    .buttonStyle(NButtonStyle(variant: .secondary, compact: true))
                    .disabled(inProgress)

                    Button("Refresh Models") {
                        Task { await model.refreshProviderModels(provider) }
                    }
                    .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
                    .disabled(inProgress)
                }
                Link(destination: provider.documentationURL) {
                    HStack(spacing: 3) {
                        Text("Get an API key")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 7))
                    }
                    .font(.nCaption)
                    .foregroundStyle(Color.nAccent)
                }
                .buttonStyle(.plain)
                Spacer()
                if model.hasAPIKey(provider) {
                    Button("Remove Key") {
                        deleteKeyPresented = true
                    }
                    .buttonStyle(NButtonStyle(variant: .danger, compact: true))
                    .disabled(inProgress)
                }
            }

            if let result = model.providerTestResults[provider] {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: result.succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(result.succeeded ? Color.nSuccess : Color.nDanger)
                        .padding(.top, 1)
                    Text(result.message)
                        .font(.nCaptionRegular)
                        .foregroundStyle(result.succeeded ? Color.nTextSecondary : Color.nDanger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let message {
                Text(message)
                    .font(.nCaptionRegular)
                    .foregroundStyle(messageIsError ? Color.nDanger : Color.nTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 8.5))
                Text("\(model.catalog.models(for: provider).count) models available")
                    .font(.nCaptionRegular)
                Text("·")
                Text(model.catalog.lastRefresh[provider] != nil
                     ? "Refreshed \(model.catalog.lastRefresh[provider]!.formatted(date: .abbreviated, time: .shortened))"
                     : "Curated list")
                    .font(.nCaptionRegular)
                Spacer()
                Button(showAdvanced ? "Hide" : "Custom models") {
                    withAnimation(.quick) { showAdvanced.toggle() }
                }
                .buttonStyle(.plain)
                .font(.nCaption)
                .foregroundStyle(Color.nAccent)
            }
            .foregroundStyle(Color.nTextTertiary)

            if showAdvanced {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        TextField("Exact model ID, e.g. gpt-4.1-mini", text: $customModelID)
                            .textFieldStyle(NotchTextFieldStyle())
                            .font(.system(size: 11, design: .monospaced))
                        Button("Add Model") {
                            model.addCustomModel(customModelID, provider: provider)
                            customModelID = ""
                        }
                        .buttonStyle(NButtonStyle(variant: .secondary, compact: true))
                        .disabled(customModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    let custom = model.catalog.customModels(for: provider)
                    if custom.isEmpty {
                        Text("Custom model IDs are useful before a provider's list is refreshed. Requests still go directly to the provider.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    } else {
                        ForEach(custom) { candidate in
                            HStack(spacing: 6) {
                                Text(candidate.id)
                                    .font(.nCaptionRegular)
                                    .foregroundStyle(Color.nTextSecondary)
                                Spacer()
                                Button {
                                    model.removeCustomModel(candidate)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.nTextTertiary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .padding(9)
            }
        }
        .padding(.vertical, 12)
        .alert("Remove \(provider.displayName) key?", isPresented: $deleteKeyPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                model.deleteProviderKey(provider)
            }
        } message: {
            Text("The key will be deleted from the macOS Keychain. Existing chats stay available, but new requests will fail until you reconnect.")
        }
    }

    private func save(verify: Bool) {
        message = nil
        Task {
            do {
                try await model.saveProviderKey(draftKey, for: provider, verify: verify)
                draftKey = ""
                messageIsError = false
                message = verify ? "Key verified and saved." : "Key saved. Use Test Connection to verify it."
            } catch {
                messageIsError = true
                message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.nCaption)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(color.opacity(0.08)))
            .overlay { Capsule().strokeBorder(color.opacity(0.14), lineWidth: 0.6) }
    }
}

private struct ShortcutsSettingsView: View {
    let model: AppModel

    @State private var recording: ShortcutAction?

    var body: some View {
        @Bindable var settings = model.settings

        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 1) {
                ForEach(ShortcutAction.allCases) { action in
                    if let binding = settings.binding(for: action) {
                        HStack(spacing: 9) {
                            Image(systemName: action.symbolName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(binding.isEnabled ? Color.nAccent : Color.nTextTertiary)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(action.displayName)
                                    .font(.nSmall)
                                    .foregroundStyle(Color.nTextPrimary)
                                Text(action.detail)
                                    .font(.nCaptionRegular)
                                    .foregroundStyle(Color.nTextTertiary)
                                if let error = model.shortcutRegistrationErrors[action] {
                                    Text(error)
                                        .font(.nCaptionRegular)
                                        .foregroundStyle(Color.nDanger)
                                }
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { binding.isEnabled },
                                set: { model.setShortcutEnabled(action, enabled: $0) }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            Button {
                                recording = action
                            } label: {
                                Text(binding.combo.displayString)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.nTextSecondary)
                                    .padding(.horizontal, 8)
                                    .frame(height: 24)
                            }
                            .buttonStyle(.plain)
                            .disabled(!binding.isEnabled)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        if action != ShortcutAction.allCases.last {
                            Divider().padding(.leading, 39)
                        }
                    }
                }
            }
            HStack {
                Text("Shortcuts are registered with the macOS hot key system. Conflicting combinations are reported per action.")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                Spacer()
                Button("Reset All") {
                    model.resetShortcuts()
                }
                .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if let action = recording {
                ShortcutRecorderSheet(model: model, action: action) {
                    recording = nil
                }
                .zIndex(5)
            }
        }
    }
}

private struct AppearanceSettingsView: View {
    let model: AppModel

    var body: some View {
        @Bindable var settings = model.settings

        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Theme") {
                SettingsRow {
                    Text("Appearance")
                        .font(.nSmall)
                    Spacer()
                    NotchSegmentedPicker(
                        selection: $settings.appearance,
                        options: AppAppearance.allCases.map { ($0, $0.displayName) }
                    )
                    .frame(width: 230)
                    .onChange(of: settings.appearance) { _, _ in
                        model.applyAppearance()
                    }
                }
                Divider().padding(.leading, 12)
                SettingsRow {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Notch surface")
                            .font(.nSmall)
                        Text("Always pure black and fully opaque to match the MacBook cutout.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    Spacer()
                    Text("BLACK")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.nTextTertiary)
                }
            }

            SettingsSection(title: "Interface") {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Density")
                            .font(.nSmall)
                        Text("Controls spacing in message lists and results.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    Spacer()
                    NotchSegmentedPicker(
                        selection: $settings.density,
                        options: InterfaceDensity.allCases.map { ($0, $0.displayName) }
                    )
                    .frame(width: 200)
                }
                Divider().padding(.leading, 12)
                SettingsRow {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Panel animations")
                            .font(.nSmall)
                        Text("Spring expansion and collapse. System Reduce Motion always takes precedence.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.animationsEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }

            SettingsSection(title: "Preview") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            NotchoraMark(size: 18)
                            Text("NOTCHORA")
                                .font(.system(size: 8.5, weight: .bold))
                                .tracking(0.9)
                                .foregroundStyle(Color.nTextPrimary)
                            Spacer()
                            Text("Connected")
                                .font(.nCaption)
                                .foregroundStyle(Color.nSuccess)
                        }
                        Text("A restrained, native surface that belongs beside macOS, not on top of it.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextSecondary)
                            .lineSpacing(1.4)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
            }
        }
    }
}

private struct PrivacySettingsView: View {
    let model: AppModel

    @State private var clearHistoryPresented = false
    @State private var deleteLocalPresented = false
    @State private var deleteKeysPresented = false
    @State private var historyOffPresented = false

    var body: some View {
        @Bindable var settings = model.settings

        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Permissions", footer: "Permissions are requested only when you use the matching feature. macOS may require a restart after granting Screen Recording access.") {
                permissionRow(.microphone)
                Divider().padding(.leading, 12)
                permissionRow(.speech)
                Divider().padding(.leading, 12)
                permissionRow(.accessibility)
                Divider().padding(.leading, 12)
                permissionRow(.screenRecording)
            }

            SettingsSection(title: "History", footer: "Chat history is stored as a local JSON file in Application Support. API keys never enter this file.") {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Keep chat history")
                            .font(.nSmall)
                        Text("Turning this off deletes stored conversations.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { settings.historyEnabled },
                        set: { newValue in
                            if newValue {
                                settings.historyEnabled = true
                            } else {
                                historyOffPresented = true
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
                Divider().padding(.leading, 12)
                SettingsRow {
                    Text("Maximum conversations")
                        .font(.nSmall)
                    Spacer()
                    Stepper(value: $settings.maxStoredConversations, in: 20...1000, step: 20) {
                        Text("\(settings.maxStoredConversations)")
                            .font(.nSmall)
                            .monospacedDigit()
                            .foregroundStyle(Color.nTextSecondary)
                    }
                    .disabled(!settings.historyEnabled)
                }
            }

            SettingsSection(title: "Data") {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Delete conversations")
                            .font(.nSmall)
                        Text("Remove all local chats. Workflows and tasks remain.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    Spacer()
                    Button("Delete…") { clearHistoryPresented = true }
                        .buttonStyle(NButtonStyle(variant: .danger, compact: true))
                }
                Divider().padding(.leading, 12)
                SettingsRow {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Delete all local data")
                            .font(.nSmall)
                        Text("Chats, tasks, workflows, and app launcher entries.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    Spacer()
                    Button("Delete…") { deleteLocalPresented = true }
                        .buttonStyle(NButtonStyle(variant: .danger, compact: true))
                }
                Divider().padding(.leading, 12)
                SettingsRow {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Remove API keys")
                            .font(.nSmall)
                        Text("Deletes all vendor credentials from Keychain.")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    Spacer()
                    Button("Remove…") { deleteKeysPresented = true }
                        .buttonStyle(NButtonStyle(variant: .danger, compact: true))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Label("Privacy by construction", systemImage: "hand.raised")
                    .font(.nSmallMedium)
                    .foregroundStyle(Color.nTextSecondary)
                Text("No analytics. No hidden clipboard polling. No screen or microphone capture without an explicit action. Context from other apps is treated as untrusted data and is never executed as instructions. Requests go directly to the provider you select over HTTPS.")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1.5)
            }
            .padding(12)
        }
        .alert("Turn off history?", isPresented: $historyOffPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Turn Off and Delete", role: .destructive) {
                settings.historyEnabled = false
                model.clearAllConversations()
                model.scheduleSave()
            }
        } message: {
            Text("Stored conversations will be deleted. You can turn history back on later.")
        }
        .alert("Delete all conversations?", isPresented: $clearHistoryPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                model.clearAllConversations()
                model.showToast(.success("Conversations deleted"))
            }
        } message: {
            Text("This cannot be undone. API keys and workflows are not affected.")
        }
        .alert("Delete all local data?", isPresented: $deleteLocalPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                model.deleteAllLocalData(includingAPIKeys: false)
            }
        } message: {
            Text("Chats, tasks, workflows, and launcher entries will be removed. API keys stay in Keychain.")
        }
        .alert("Remove all API keys?", isPresented: $deleteKeysPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Remove Keys", role: .destructive) {
                model.deleteAllAPIKeys()
            }
        } message: {
            Text("All provider credentials will be deleted from the macOS Keychain.")
        }
        .onAppear {
            model.permissions.refresh()
        }
    }

    private func permissionRow(_ permission: PermissionStateKind) -> some View {
        let state = state(for: permission)
        return HStack(spacing: 9) {
            Image(systemName: permission.symbolName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(state == .granted ? Color.nSuccess : Color.nTextSecondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(permission.title)
                    .font(.nSmall)
                Text(permission.detail)
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                    .lineLimit(2)
            }
            Spacer()
            Text(state.label)
                .font(.nCaption)
                .foregroundStyle(state == .granted ? Color.nSuccess : Color.nTextTertiary)
            if state == .granted {
                Button("Settings") {
                    model.permissions.openSettings(for: permission)
                }
                .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
            } else {
                Button(permission == .accessibility || permission == .screenRecording ? "Request" : "Allow") {
                    request(permission)
                }
                .buttonStyle(NButtonStyle(variant: .secondary, compact: true))
                Button("Settings") {
                    model.permissions.openSettings(for: permission)
                }
                .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func state(for permission: PermissionStateKind) -> PermissionState {
        switch permission {
        case .microphone: model.permissions.microphone
        case .speech: model.permissions.speechRecognition
        case .accessibility: model.permissions.accessibility
        case .screenRecording: model.permissions.screenRecording
        }
    }

    private func request(_ permission: PermissionStateKind) {
        switch permission {
        case .microphone:
            Task { await model.permissions.requestMicrophone() }
        case .speech:
            Task { await model.permissions.requestSpeechRecognition() }
        case .accessibility:
            model.permissions.requestAccessibility()
        case .screenRecording:
            model.permissions.requestScreenRecording()
        }
    }
}

private struct AboutSettingsView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                NotchoraMark(size: 64)
                Text("NOTCHORA")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.nTextPrimary)
                Text("Your AI. One notch away.")
                    .font(.nSmall)
                    .foregroundStyle(Color.nTextSecondary)
                Text("Version \(version) (\(build))")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
            .padding(.top, 10)

            HStack(spacing: 8) {
                aboutFact("Native", detail: "SwiftUI + AppKit", symbol: "swift")
                aboutFact("Private", detail: "Keychain + local history", symbol: "lock.shield")
                aboutFact("Direct", detail: "No proxy server", symbol: "arrow.up.forward")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("A control center, not another chat window.")
                    .font(.nSmallMedium)
                    .foregroundStyle(Color.nTextPrimary)
                Text("NOTCHORA lives at the top edge of macOS. It keeps conversations with OpenAI, Anthropic, and Google Gemini in one native surface, with explicit context capture, independent parallel streams, and real background tasks.")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextSecondary)
                    .lineSpacing(1.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("No analytics. No tracking. API keys and conversations stay on this Mac except when you send a request to the provider you chose.")
                .font(.nCaptionRegular)
                .foregroundStyle(Color.nTextTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private func aboutFact(_ title: String, detail: String, symbol: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.nAccent)
            Text(title)
                .font(.nCaption)
                .foregroundStyle(Color.nTextPrimary)
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(Color.nTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
