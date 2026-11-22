import AppKit
import NotchoraCore
import SwiftUI

struct ShortcutRecorderSheet: View {
    let model: AppModel
    let action: ShortcutAction
    let onClose: () -> Void

    @State private var combo: KeyCombo?
    @State private var message = "Press a key combination."

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: action.symbolName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.nAccent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(action.displayName)
                        .font(.nHeadline)
                        .foregroundStyle(Color.nTextPrimary)
                    Text("Global Shortcut")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                }
                Spacer()
            }
            .padding(16)

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black)
                        .frame(height: 74)
                    if let combo {
                        Text(combo.displayString)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.nTextPrimary)
                    } else {
                        Text("Waiting for keys…")
                            .font(.nSmall)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.nHairline, lineWidth: 0.8)
                }

                Text(message)
                    .font(.nCaption)
                    .foregroundStyle(combo == nil ? Color.nTextTertiary : Color.nTextSecondary)

                KeyCaptureView { keyCode, modifiers in
                    guard keyCode != 53 else {
                        message = "Press a key combination, or Cancel."
                        return
                    }
                    let combo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
                    guard combo.isSafeGlobalShortcut else {
                        message = "Include ⌘, ⌥, or ⌃ so typing is not intercepted."
                        return
                    }
                    self.combo = combo
                    message = model.settings.duplicateShortcut(for: action, combo: combo)
                        .map { "This combination is already used by \($0.displayName)." }
                        ?? "Ready. Apply to register this shortcut."
                }
                .frame(height: 1)
                .opacity(0.01)

                Text("Avoid combinations already used by macOS. Registration failures appear in the list after you apply.")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)

            HStack {
                Button("Clear") {
                    if var binding = model.settings.binding(for: action) {
                        binding.isEnabled = false
                        model.updateShortcut(binding)
                    }
                    onClose()
                }
                .buttonStyle(NButtonStyle(variant: .ghost))
                Spacer()
                Button("Cancel") { onClose() }
                    .buttonStyle(NButtonStyle(variant: .ghost))
                Button("Apply") {
                    guard let combo else { return }
                    let enabled = model.settings.binding(for: action)?.isEnabled ?? true
                    model.updateShortcut(ShortcutBinding(action: action, combo: combo, isEnabled: enabled))
                    onClose()
                }
                .buttonStyle(NButtonStyle(variant: .primary))
                .disabled(combo == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Hairline() }
        }
        .frame(maxWidth: 560, maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
        .onAppear {
            model.shortcutsRegistrationRequested?([])
        }
        .onDisappear {
            model.reapplyShortcuts()
        }
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    let onCapture: (UInt32, ShortcutModifiers) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class KeyCaptureNSView: NSView {
    var onCapture: ((UInt32, ShortcutModifiers) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }
        var modifiers: ShortcutModifiers = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        onCapture?(UInt32(event.keyCode), modifiers)
    }
}
