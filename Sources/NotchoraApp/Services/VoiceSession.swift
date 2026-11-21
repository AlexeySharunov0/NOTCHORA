@preconcurrency import AVFoundation
import Foundation
import NotchoraCore
import Observation
@preconcurrency import Speech

enum VoicePhase: String, Hashable, Sendable {
    case idle
    case requestingPermission
    case listening
    case processing
    case responding
    case interrupted
    case ready
    case error

    var label: String {
        switch self {
        case .idle: "Voice"
        case .requestingPermission: "Requesting access"
        case .listening: "Listening"
        case .processing: "Thinking"
        case .responding: "Speaking"
        case .interrupted: "Interrupted"
        case .ready: "Ready"
        case .error: "Unavailable"
        }
    }
}

@MainActor
@Observable
final class VoiceSession {
    var phase: VoicePhase = .idle
    var transcript = ""
    var lastResponse = ""
    var errorMessage: String?
    var errorPermission: PermissionStateKind?
    var audioLevel: Float = 0
    var levels: [Float] = Array(repeating: 0, count: 42)
    var isOnDevice = false
    var autoSpeak = true
    var speechRate: Double = 0.5
    var localeIdentifier = ""

    var onSend: (@MainActor (String) async throws -> String)?

    @ObservationIgnored private let permissions: PermissionCenter
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var speechRecognizer: SFSpeechRecognizer?
    @ObservationIgnored private var responseTask: Task<Void, Never>?
    @ObservationIgnored private var speechWatcher: Task<Void, Never>?
    @ObservationIgnored private var isTapInstalled = false
    @ObservationIgnored private var levelCounter = 0

    init(permissions: PermissionCenter) {
        self.permissions = permissions
    }

    var isBusy: Bool {
        phase == .listening || phase == .processing || phase == .responding
    }

    func configure(autoSpeak: Bool, speechRate: Double, localeIdentifier: String) {
        self.autoSpeak = autoSpeak
        self.speechRate = min(max(speechRate, 0.3), 0.65)
        self.localeIdentifier = localeIdentifier
    }

    func startListening() async {
        guard phase != .listening else {
            finishAndSend()
            return
        }
        if phase == .processing || phase == .responding {
            interrupt()
            return
        }

        phase = .requestingPermission
        errorMessage = nil
        errorPermission = nil
        transcript = ""
        lastResponse = ""
        levels = Array(repeating: 0, count: levels.count)

        await permissions.requestMicrophone()
        guard permissions.microphone == .granted else {
            fail(
                "Microphone access is required for Voice Mode.",
                permission: .microphone
            )
            return
        }
        await permissions.requestSpeechRecognition()
        guard permissions.speechRecognition == .granted else {
            fail(
                "Speech Recognition access is required to turn your voice into text.",
                permission: .speech
            )
            return
        }

        let locale = resolvedLocale()
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            fail(
                "Speech recognition is not available for \(locale.identifier) right now.",
                permission: .speech
            )
            return
        }
        speechRecognizer = recognizer
        isOnDevice = recognizer.supportsOnDeviceRecognition

        do {
            try beginAudioCapture(with: recognizer)
            phase = .listening
        } catch {
            fail(error.localizedDescription, permission: .microphone)
        }
    }

    func finishAndSend() {
        guard phase == .listening else { return }
        stopAudioCapture()
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            phase = .ready
            errorMessage = "I didn't catch any speech. Try again and speak a little closer to the microphone."
            return
        }
        phase = .processing
        responseTask?.cancel()
        responseTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard let onSend = self.onSend else {
                    throw AIProviderError.network("Voice routing is not configured.")
                }
                let response = try await onSend(text)
                try Task.checkCancellation()
                self.lastResponse = response
                if self.autoSpeak {
                    self.speak(response)
                } else {
                    self.phase = .ready
                }
            } catch is CancellationError {
                self.phase = .ready
            } catch {
                self.phase = .error
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.errorPermission = nil
            }
        }
    }

    func stopListening() {
        guard phase == .listening else { return }
        stopAudioCapture()
        phase = .ready
    }

    func speak(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .ready
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        let language = localeIdentifier.isEmpty ? Locale.current.identifier : localeIdentifier
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = Float(speechRate)
        utterance.prefersAssistiveTechnologySettings = true
        phase = .responding
        synthesizer.speak(utterance)

        speechWatcher?.cancel()
        speechWatcher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(180))
                guard let self else { return }
                if !self.synthesizer.isSpeaking {
                    if self.phase == .responding {
                        self.phase = .ready
                    }
                    return
                }
            }
        }
    }

    func stopSpeaking() {
        speechWatcher?.cancel()
        speechWatcher = nil
        synthesizer.stopSpeaking(at: .immediate)
        phase = .ready
    }

    func interrupt() {
        responseTask?.cancel()
        responseTask = nil
        stopAudioCapture()
        speechWatcher?.cancel()
        synthesizer.stopSpeaking(at: .immediate)
        phase = .interrupted
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard let self, self.phase == .interrupted else { return }
            self.phase = .ready
        }
    }

    func cancel() {
        responseTask?.cancel()
        responseTask = nil
        speechWatcher?.cancel()
        speechWatcher = nil
        stopAudioCapture()
        synthesizer.stopSpeaking(at: .immediate)
        phase = .idle
        audioLevel = 0
        levels = Array(repeating: 0, count: levels.count)
    }

    func resetError() {
        errorMessage = nil
        errorPermission = nil
        phase = .idle
    }

    private func beginAudioCapture(with recognizer: SFSpeechRecognizer) throws {
        stopAudioCapture()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw VoiceError.audioInputUnavailable
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            request.append(buffer)
            let level = Self.normalizedLevel(from: buffer)
            Task { @MainActor [weak self] in
                self?.pushLevel(level)
            }
        }
        isTapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            stopAudioCapture()
            throw error
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let message = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let transcript {
                    self.transcript = transcript
                }
                if isFinal, self.phase == .listening {
                    self.finishAndSend()
                    return
                }
                if let message, self.phase == .listening {
                    self.fail(message, permission: .speech)
                }
            }
        }
    }

    private func stopAudioCapture() {
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        audioLevel = 0
    }

    private func pushLevel(_ level: Float) {
        audioLevel = level
        levelCounter += 1
        if levelCounter % 2 == 0 {
            levels.removeFirst()
            levels.append(level)
        }
    }

    private func fail(_ message: String, permission: PermissionStateKind?) {
        stopAudioCapture()
        phase = .error
        errorMessage = message
        errorPermission = permission
    }

    private func resolvedLocale() -> Locale {
        if !localeIdentifier.isEmpty, SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) != nil {
            return Locale(identifier: localeIdentifier)
        }
        return Locale.current
    }

    private static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<count {
            let sample = channel[index]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(count))
        let decibels = 20 * log10(max(rms, 0.000_001))
        let normalized = (decibels + 55) / 55
        return min(max(normalized, 0), 1)
    }
}

enum VoiceError: Error, LocalizedError, Sendable {
    case audioInputUnavailable

    var errorDescription: String? {
        switch self {
        case .audioInputUnavailable:
            "No audio input is available. Check the selected microphone in System Settings."
        }
    }
}
