import SwiftUI

struct ScreenCapturePickerSheet: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var mode: ScreenCaptureMode = .selectedArea

    private var permissionGranted: Bool {
        model.permissions.screenRecording == .granted || model.screenCaptureService.hasPermission
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 14) {
                Text("Choose what to share with \(model.activeModel.displayName). The image is attached to the composer; nothing is sent until you press Send.")
                    .font(.nSmall)
                    .foregroundStyle(Color.nTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1.5)

                VStack(spacing: 5) {
                    ForEach(ScreenCaptureMode.allCases) { candidate in
                        modeRow(candidate)
                    }
                }

                if !permissionGranted {
                    permissionNotice
                }

                HStack(spacing: 6) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 9))
                    Text("NOTCHORA hides itself before capture. Screenshots are stored only in the local chat that uses them.")
                        .font(.nCaptionRegular)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Color.nTextTertiary)
            }
            .padding(16)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(NButtonStyle(variant: .ghost))
                Spacer()
                Button("Capture") {
                    dismiss()
                    Task {
                        try? await Task.sleep(for: .milliseconds(120))
                        model.captureScreen(mode: mode)
                    }
                }
                .buttonStyle(NButtonStyle(variant: .primary))
                .disabled(!permissionGranted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Hairline() }
        }
        .frame(width: 470, height: 430)
        .background(Color.nPanelSolid)
        .onAppear {
            model.permissions.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.nAccentSoft)
                    .frame(width: 30, height: 30)
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.nAccent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Share Screen with AI")
                    .font(.nHeadline)
                    .foregroundStyle(Color.nTextPrimary)
                Text("ScreenCaptureKit · macOS")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.nTextTertiary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func modeRow(_ candidate: ScreenCaptureMode) -> some View {
        Button {
            mode = candidate
        } label: {
            HStack(spacing: 10) {
                Image(systemName: candidate.symbolName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(mode == candidate ? Color.nAccent : Color.nTextSecondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(candidate.title)
                        .font(.nSmallMedium)
                        .foregroundStyle(Color.nTextPrimary)
                    Text(candidate.detail)
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                }
                Spacer()
                Image(systemName: mode == candidate ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(mode == candidate ? Color.nAccent : Color.nTextTertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(mode == candidate ? Color.nAccentSoft : Color.primary.opacity(0.025))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(mode == candidate ? Color.nAccent.opacity(0.30) : Color.nHairline, lineWidth: 0.8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var permissionNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Screen Recording permission is required", systemImage: "exclamationmark.triangle.fill")
                .font(.nCaption)
                .foregroundStyle(Color.nWarning)
            Text("macOS may need to restart NOTCHORA after you grant access.")
                .font(.nCaptionRegular)
                .foregroundStyle(Color.nTextTertiary)
            HStack(spacing: 7) {
                Button("Allow") {
                    model.permissions.requestScreenRecording()
                }
                .buttonStyle(NButtonStyle(variant: .secondary, compact: true))
                Button("Open Settings") {
                    model.openScreenRecordingSettings()
                }
                .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.nWarning.opacity(0.07))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.nWarning.opacity(0.16), lineWidth: 0.8)
        }
    }
}
