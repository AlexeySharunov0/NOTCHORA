import Carbon.HIToolbox
import Foundation
import NotchoraCore

private let notchoraHotKeySignature: OSType = 0x4E544852 // 'NTHR'

private func notchoraHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    return manager.handle(event: event)
}

final class GlobalHotKeyManager: @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [UInt32: ShortcutAction] = [:]
    private var references: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    var onAction: (@Sendable (ShortcutAction) -> Void)?

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            notchoraHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        if status != noErr {
            eventHandler = nil
        }
    }

    deinit {
        for reference in references {
            UnregisterEventHotKey(reference)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    /// Replaces every registered shortcut. Returns a per-action explanation for
    /// shortcuts macOS refused (usually a conflict with another app).
    func update(bindings: [ShortcutBinding]) -> [ShortcutAction: String] {
        for reference in references {
            UnregisterEventHotKey(reference)
        }
        references.removeAll()
        lock.lock()
        handlers.removeAll()
        nextID = 1
        lock.unlock()

        var errors: [ShortcutAction: String] = [:]
        for binding in bindings where binding.isEnabled {
            guard binding.combo.isSafeGlobalShortcut else {
                errors[binding.action] = "A global shortcut needs ⌘, ⌥, or ⌃."
                continue
            }
            let id = nextID
            nextID += 1
            var reference: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: notchoraHotKeySignature, id: id)
            let status = RegisterEventHotKey(
                binding.combo.keyCode,
                binding.combo.modifiers.rawValue,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &reference
            )
            if status == noErr, let reference {
                references.append(reference)
                lock.lock()
                handlers[id] = binding.action
                lock.unlock()
            } else {
                errors[binding.action] = "macOS could not register \(binding.combo.displayString). It may already be in use."
            }
        }
        return errors
    }

    fileprivate func handle(event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr, hotKeyID.signature == notchoraHotKeySignature else {
            return OSStatus(eventNotHandledErr)
        }

        lock.lock()
        let action = handlers[hotKeyID.id]
        lock.unlock()
        guard let action else { return OSStatus(eventNotHandledErr) }

        let callback = onAction
        DispatchQueue.main.async {
            callback?(action)
        }
        return noErr
    }
}
