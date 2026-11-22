import SwiftUI

struct VoiceOverlay: View {
    let model: AppModel

    private var voice: VoiceSession { model.voiceSession }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 14) {
                waveform
                phaseLabel
                transcript
                controls
                privacyNote
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(Color.nAccentSoft)
                    .frame(width: 30, height: 30)
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.nAccent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Voice Mode")
                    .font(.nHeadline)
                    .foregroundStyle(Color.nTextPrimary)
                HStack(spacing: 5) {
                    Text(model.activeModel.displayName)
                    if voice.isOnDevice {
                        Text("· On-device")
                    }
                }
                .font(.nCaptionRegular)
                .foregroundStyle(Color.nTextTertiary)
            }
            Spacer()
            Button {
                model.stopVoiceMode()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Close Voice Mode")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var waveform: some View {
        ZStack {
            VoiceWaveform(
                levels: voice.levels,
                phase: voice.phase,
                color: waveColor,
                height: 78
            )
            .padding(.horizontal, 24)
        }
        .frame(height: 100)
    }

    private var phaseLabel: some View {
        VStack(spacing: 5) {
            Text(voice.phase.label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.nTextPrimary)
            if voice.phase == .listening {
                Text(voice.transcript.isEmpty ? "Speak naturally. Tap send when you're done." : "Listening to you…")
                    .font(.nCaption)
                    .foregroundStyle(Color.nTextTertiary)
            } else if voice.phase == .processing {
                Text("Using \(model.activeModel.displayName)")
                    .font(.nCaption)
                    .foregroundStyle(Color.nTextTertiary)
            } else if voice.phase == .responding {
                Text("Speak or tap Interrupt at any time")
                    .font(.nCaption)
                    .foregroundStyle(Color.nTextTertiary)
            }
        }
    }

    @ViewBuilder
    private var transcript: some View {
        if voice.phase == .error, let message = voice.errorMessage {
            VStack(alignment: .leading, spacing: 10) {
                Text(message)
                    .font(.nSmall)
                    .foregroundStyle(Color.nTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 7) {
                    if let permission = voice.errorPermission {
                        Button("Open Settings") {
                            model.permissions.openSettings(for: permission)
                        }
                        .buttonStyle(NButtonStyle(variant: .secondary, compact: true))
                    }
                    if !model.hasAPIKey(model.activeSelection.providerID) {
                        Button("Connect Provider") {
                            model.stopVoiceMode()
                            model.requestSettings(.providers)
                        }
                        .buttonStyle(NButtonStyle(variant: .primary, compact: true))
                    }
                    Button("Try Again") {
                        voice.resetError()
                        Task { await voice.startListening() }
                    }
                    .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if !voice.transcript.isEmpty {
            ScrollView(.vertical, showsIndicators: false) {
                Text(voice.transcript)
                    .font(.nBody)
                    .foregroundStyle(Color.nTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(2)
            }
            .frame(maxHeight: 72)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black)
            )
        } else if voice.phase == .responding, !voice.lastResponse.isEmpty {
            Text(voice.lastResponse)
                .font(.nSmall)
                .foregroundStyle(Color.nTextSecondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black)
                )
        }
    }

    private var controls: some View {
        HStack(spacing: 9) {
            Button {
                model.toggleVoiceListening()
            } label: {
                Label(primaryTitle, systemImage: primarySymbol)
                    .frame(minWidth: 112)
            }
            .buttonStyle(NButtonStyle(variant: .primary))

            if voice.phase == .responding {
                Button("Interrupt") {
                    voice.interrupt()
                }
                .buttonStyle(NButtonStyle(variant: .secondary))
            }

            if voice.phase == .ready || voice.phase == .interrupted {
                Button("Done") {
                    model.stopVoiceMode()
                }
                .buttonStyle(NButtonStyle(variant: .ghost))
            }

            Spacer()

            Toggle(isOn: Binding(
                get: { voice.autoSpeak },
                set: { newValue in
                    voice.autoSpeak = newValue
                    model.settings.voiceAutoSpeak = newValue
                    if !newValue { voice.stopSpeaking() }
                }
            )) {
                Label("Speak replies", systemImage: "speaker.wave.2")
                    .font(.nCaption)
                    .foregroundStyle(Color.nTextSecondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(Color.nAccent)
        }
    }

    private var privacyNote: some View {
        HStack(spacing: 5) {
            Image(systemName: "mic.slash")
                .font(.system(size: 8.5, weight: .medium))
            Text("The microphone is active only while Listening. Speech is processed by Apple's Speech framework and stays on-device when available.")
                .font(.nCaptionRegular)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.nTextTertiary)
    }

    private var primaryTitle: String {
        switch voice.phase {
        case .listening: "Stop & Send"
        case .processing, .responding: "Interrupt"
        case .idle, .ready, .interrupted, .error: "Start Speaking"
        case .requestingPermission: "Requesting…"
        }
    }

    private var primarySymbol: String {
        switch voice.phase {
        case .listening: "arrow.up"
        case .processing, .responding: "stop.fill"
        case .idle, .ready, .interrupted, .error: "mic.fill"
        case .requestingPermission: "ellipsis"
        }
    }

    private var waveColor: Color {
        switch voice.phase {
        case .listening: .nAccent
        case .processing: .nTeal
        case .responding: .nSuccess
        case .interrupted: .nWarning
        case .error: .nDanger
        default: .nTextTertiary
        }
    }
}
