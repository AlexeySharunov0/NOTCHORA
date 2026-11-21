import Foundation

public enum AppAppearance: String, Codable, CaseIterable, Hashable, Sendable {
    case system
    case light
    case dark

    public var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

public enum InterfaceDensity: String, Codable, CaseIterable, Hashable, Sendable {
    case comfortable
    case compact

    public var displayName: String {
        switch self {
        case .comfortable: "Comfortable"
        case .compact: "Compact"
        }
    }
}

public enum DefaultBehavior: String, Codable, CaseIterable, Hashable, Sendable {
    case lastConversation
    case newChat

    public var displayName: String {
        switch self {
        case .lastConversation: "Continue last chat"
        case .newChat: "Start a new chat"
        }
    }
}

public enum DisplayPreference: String, Codable, CaseIterable, Hashable, Sendable {
    case activeScreen
    case builtIn
    case main

    public var displayName: String {
        switch self {
        case .activeScreen: "Screen with pointer"
        case .builtIn: "Built-in display"
        case .main: "Main display"
        }
    }
}

public enum ShortcutAction: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case openPanel
    case newChat
    case voiceMode
    case selectedText
    case multiAI
    case hidePanel

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openPanel: "Open NOTCHORA"
        case .newChat: "New Chat"
        case .voiceMode: "Voice Mode"
        case .selectedText: "Ask Selected Text"
        case .multiAI: "Multi-AI"
        case .hidePanel: "Hide Panel"
        }
    }

    public var detail: String {
        switch self {
        case .openPanel: "Show or focus the notch panel."
        case .newChat: "Open the panel with a fresh conversation."
        case .voiceMode: "Start a voice session immediately."
        case .selectedText: "Read the frontmost app's selection through Accessibility."
        case .multiAI: "Open a new parallel model session."
        case .hidePanel: "Collapse and dismiss the panel."
        }
    }

    public var symbolName: String {
        switch self {
        case .openPanel: "sparkles"
        case .newChat: "square.and.pencil"
        case .voiceMode: "waveform"
        case .selectedText: "text.cursor"
        case .multiAI: "square.split.2x2"
        case .hidePanel: "chevron.down"
        }
    }
}

public struct ShortcutModifiers: OptionSet, Hashable, Sendable, Codable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    // Values deliberately match Carbon's modifier masks. The core module
    // remains free of Carbon so it can be tested on any machine.
    public static let command = ShortcutModifiers(rawValue: 1 << 8)
    public static let shift = ShortcutModifiers(rawValue: 1 << 9)
    public static let option = ShortcutModifiers(rawValue: 1 << 11)
    public static let control = ShortcutModifiers(rawValue: 1 << 12)

    public static let none: ShortcutModifiers = []

    public var glyphs: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(UInt32.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct KeyCombo: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: ShortcutModifiers

    public init(keyCode: UInt32, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var keyLabel: String {
        KeyCodeNames.label(for: keyCode)
    }

    public var displayString: String {
        "\(modifiers.glyphs)\(keyLabel)"
    }

    /// A global shortcut without a modifier would steal ordinary typing.
    public var isSafeGlobalShortcut: Bool {
        !modifiers.intersection([.command, .option, .control]).isEmpty
    }

    public static let space = KeyCombo(keyCode: 49, modifiers: [.option])
    public static let optionN = KeyCombo(keyCode: 45, modifiers: [.option])
    public static let optionV = KeyCombo(keyCode: 9, modifiers: [.option])
    public static let optionS = KeyCombo(keyCode: 1, modifiers: [.option])
    public static let optionM = KeyCombo(keyCode: 46, modifiers: [.option])
    public static let optionPeriod = KeyCombo(keyCode: 47, modifiers: [.option])
}

public struct ShortcutBinding: Identifiable, Codable, Hashable, Sendable {
    public var action: ShortcutAction
    public var combo: KeyCombo
    public var isEnabled: Bool

    public var id: ShortcutAction { action }

    public init(action: ShortcutAction, combo: KeyCombo, isEnabled: Bool = true) {
        self.action = action
        self.combo = combo
        self.isEnabled = isEnabled
    }

    public static let defaults: [ShortcutBinding] = [
        ShortcutBinding(action: .openPanel, combo: .space),
        ShortcutBinding(action: .newChat, combo: .optionN),
        ShortcutBinding(action: .voiceMode, combo: .optionV),
        ShortcutBinding(action: .selectedText, combo: .optionS),
        ShortcutBinding(action: .multiAI, combo: .optionM),
        ShortcutBinding(action: .hidePanel, combo: .optionPeriod)
    ]
}

public enum KeyCodeNames {
    private static let names: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
        39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "Esc", 36: "↩", 76: "⌤", 96: "F5",
        97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13",
        106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help",
        115: "Home", 116: "Page Up", 117: "⌦", 118: "F4", 119: "End", 120: "F2",
        121: "Page Down", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    public static func label(for keyCode: UInt32) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }
}
