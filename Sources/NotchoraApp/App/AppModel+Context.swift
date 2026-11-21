import AppKit
import Foundation
import NotchoraCore

extension AppModel {
    func captureSelectedText() {
        permissions.refresh()
        _ = NSWorkspace.shared.frontmostApplication

        guard selectedTextService.isTrusted else {
            selectionFailure = SelectionFailure(
                reason: .accessibilityDenied,
                title: "Accessibility access is off",
                message: "NOTCHORA reads selected text only when you invoke this command. macOS requires Accessibility access for that read. You can also copy text and use the Clipboard action.",
                sourceApplication: NSWorkspace.shared.frontmostApplication?.localizedName
            )
            setPresentation(.expanded)
            return
        }

        do {
            let result = try selectedTextService.readSelectedText()
            selectedTextOffer = SelectedTextOffer(
                text: result.text,
                sourceApplication: result.applicationName,
                isEditable: true
            )
            setPresentation(.expanded)
        } catch let error as SelectedTextError {
            let reason: SelectionFailure.Reason
            switch error {
            case .accessibilityDenied: reason = .accessibilityDenied
            case .noSelection: reason = .noSelection
            default: reason = .unavailable
            }
            selectionFailure = SelectionFailure(
                reason: reason,
                title: reason == .noSelection ? "No text is selected" : "Selection unavailable",
                message: error.errorDescription ?? "The selection could not be read.",
                sourceApplication: NSWorkspace.shared.frontmostApplication?.localizedName
            )
            setPresentation(.expanded)
        } catch {
            selectionFailure = SelectionFailure(
                reason: .unavailable,
                title: "Selection unavailable",
                message: error.localizedDescription,
                sourceApplication: NSWorkspace.shared.frontmostApplication?.localizedName
            )
            setPresentation(.expanded)
        }
    }

    func attachClipboardText() {
        guard let text = ClipboardService.readText() else {
            showToast(.warning("Clipboard is empty", detail: "Copy some text first, then try again."))
            return
        }
        contextDraft = ContextDraft(
            source: .clipboard,
            title: "Clipboard text",
            text: text
        )
        if presentation == .compact || presentation == .hidden {
            setPresentation(.expanded)
        }
        route = .chat
        composerFocusRequest += 1
    }

    func useClipboardAsContext() {
        guard let text = ClipboardService.readText() else {
            showToast(.warning("Clipboard is empty", detail: "Copy some text first, then try again."))
            return
        }
        selectedTextOffer = SelectedTextOffer(
            text: text,
            sourceApplication: "Clipboard",
            isEditable: true
        )
        selectionFailure = nil
        setPresentation(.expanded)
    }

    func requestAccessibilityAccess() {
        permissions.requestAccessibility()
        showToast(.info(
            "Accessibility requested",
            detail: "Enable NOTCHORA in System Settings → Privacy & Security → Accessibility, then try again."
        ))
    }

    func openAccessibilitySettings() {
        permissions.openSettings(for: .accessibility)
    }

    func openScreenRecordingSettings() {
        permissions.openSettings(for: .screenRecording)
    }

    func copyToClipboard(_ text: String) {
        ClipboardService.write(text)
        showToast(.success("Copied"))
    }

    func captureScreen(mode: ScreenCaptureMode) {
        permissions.refresh()
        guard permissions.screenRecording == .granted || screenCaptureService.hasPermission else {
            permissions.requestScreenRecording()
            showToast(ToastMessage(
                kind: .warning,
                title: "Screen Recording permission needed",
                detail: "Allow NOTCHORA in System Settings → Privacy & Security → Screen Recording. macOS may require a restart after granting it.",
                actionTitle: "Open Settings",
                action: { [weak self] in self?.openScreenRecordingSettings() }
            ))
            return
        }
        guard !isCapturingScreen else { return }

        let restorePresentation: PanelPresentation = presentation == .workspace ? .workspace :
            (presentation == .expanded ? .expanded : .expanded)
        let preferredPID = previousFrontmostPID
        isCapturingScreen = true
        setPresentation(.hidden)

        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(180))
            do {
                let result: ScreenCaptureResult
                switch mode {
                case .fullScreen:
                    let screen = activeScreen()
                    result = try await self.screenCaptureService.captureFullScreen(screen: screen)
                case .currentWindow:
                    result = try await self.screenCaptureService.captureCurrentWindow(preferredPID: preferredPID)
                case .selectedArea:
                    result = try await self.screenCaptureService.captureSelectedArea()
                }

                guard let attachment = self.screenCaptureService.attachment(from: result) else {
                    throw ScreenCaptureError.captureFailed("The image could not be encoded.")
                }
                self.contextDraft = ContextDraft(
                    source: .screenshot,
                    title: result.label,
                    text: "",
                    attachment: attachment
                )
                self.route = .chat
                self.setPresentation(restorePresentation)
                self.composerFocusRequest += 1
                self.showToast(.success(
                    "Screen attached",
                    detail: "Review it in the composer before sending. Nothing has been sent yet."
                ))
            } catch let error as ScreenCaptureError {
                if case .selectionCancelled = error {
                    self.showToast(.info("Screen capture cancelled"))
                } else {
                    self.showToast(ToastMessage(
                        kind: .error,
                        title: "Could not capture screen",
                        detail: error.errorDescription,
                        actionTitle: "Open Settings",
                        action: { [weak self] in self?.openScreenRecordingSettings() }
                    ))
                }
                self.setPresentation(restorePresentation)
            } catch {
                self.showToast(.error("Could not capture screen", detail: error.localizedDescription))
                self.setPresentation(restorePresentation)
            }
            self.isCapturingScreen = false
            self.permissions.refresh()
        }
    }

    func removeContextAttachment() {
        contextDraft = nil
    }

    func activeScreen() -> NSScreen {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    func dismissSelectionOffer() {
        selectedTextOffer = nil
    }

    func dismissSelectionFailure() {
        selectionFailure = nil
    }
}
