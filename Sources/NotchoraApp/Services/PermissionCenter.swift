import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import Observation
import Speech

enum PermissionState: String, Hashable, Sendable {
    case notDetermined
    case granted
    case denied
    case restricted
    case unavailable

    var label: String {
        switch self {
        case .notDetermined: "Not requested"
        case .granted: "Allowed"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .unavailable: "Unavailable"
        }
    }
}

@MainActor
@Observable
final class PermissionCenter {
    var microphone: PermissionState = .notDetermined
    var speechRecognition: PermissionState = .notDetermined
    var accessibility: PermissionState = .notDetermined
    var screenRecording: PermissionState = .notDetermined

    var lastRefresh = Date()

    init() {
        refresh()
    }

    func refresh() {
        microphone = Self.map(AVCaptureDevice.authorizationStatus(for: .audio))
        speechRecognition = Self.map(SFSpeechRecognizer.authorizationStatus())
        accessibility = AXIsProcessTrusted() ? .granted : .denied
        screenRecording = CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
        lastRefresh = Date()
    }

    func requestMicrophone() async {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
            microphone = granted ? .granted : .denied
        } else {
            refresh()
        }
    }

    func requestSpeechRecognition() async {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            speechRecognition = Self.map(status)
        } else {
            refresh()
        }
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        refresh()
    }

    func openSettings(for permission: PermissionStateKind) {
        let anchor: String
        switch permission {
        case .microphone: anchor = "Privacy_Microphone"
        case .speech: anchor = "Privacy_SpeechRecognition"
        case .accessibility: anchor = "Privacy_Accessibility"
        case .screenRecording: anchor = "Privacy_ScreenCapture"
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func map(_ status: AVAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized: .granted
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .unavailable
        }
    }

    private static func map(_ status: SFSpeechRecognizerAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized: .granted
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .unavailable
        }
    }
}

enum PermissionStateKind: String, CaseIterable, Identifiable, Sendable {
    case microphone
    case speech
    case accessibility
    case screenRecording

    var id: String { rawValue }

    var title: String {
        switch self {
        case .microphone: "Microphone"
        case .speech: "Speech Recognition"
        case .accessibility: "Accessibility"
        case .screenRecording: "Screen Recording"
        }
    }

    var detail: String {
        switch self {
        case .microphone: "Required only while you are recording a voice message."
        case .speech: "Converts your voice into text on this Mac when available."
        case .accessibility: "Lets NOTCHORA read the text you explicitly select in another app."
        case .screenRecording: "Required only when you choose to share a screen capture with a model."
        }
    }

    var symbolName: String {
        switch self {
        case .microphone: "mic"
        case .speech: "waveform"
        case .accessibility: "accessibility"
        case .screenRecording: "rectangle.dashed"
        }
    }
}
