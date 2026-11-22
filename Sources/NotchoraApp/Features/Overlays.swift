import NotchoraCore
import SwiftUI

struct ToastView: View {
    let model: AppModel
    let toast: ToastMessage

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 17, height: 17)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.nSmallMedium)
                    .foregroundStyle(Color.nTextPrimary)
                if let detail = toast.detail {
                    Text(detail)
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                }
            }

            Spacer(minLength: 4)

            if let actionTitle = toast.actionTitle, let action = toast.action {
                Button(actionTitle) {
                    action()
                    model.dismissToast()
                }
                .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
            }

            Button {
                model.dismissToast()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.nTextTertiary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: 500, alignment: .leading)
        .background(Color.black)
    }

    private var icon: String {
        switch toast.kind {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch toast.kind {
        case .info: .nAccent
        case .success: .nSuccess
        case .warning: .nWarning
        case .error: .nDanger
        }
    }
}

struct SelectionActionOverlay: View {
    let model: AppModel
    let offer: SelectedTextOffer

    @State private var editedText: String = ""

    private let columns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.nAccentSoft)
                            .frame(width: 30, height: 30)
                        Image(systemName: "text.cursor")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.nAccent)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Selected text")
                            .font(.nHeadline)
                            .foregroundStyle(Color.nTextPrimary)
                        Text(offer.sourceApplication.map { "From \($0)" } ?? "From the frontmost app")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    Spacer()
                    Button {
                        model.dismissSelectionOffer()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderless)
                }

                TextEditor(text: $editedText)
                    .font(.nSmall)
                    .foregroundStyle(Color.nTextPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 96)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.black)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.nHairline, lineWidth: 0.8)
                    }

                LazyVGrid(columns: columns, spacing: 7) {
                    ForEach(SelectionAction.allCases) { action in
                        Button {
                            let updated = SelectedTextOffer(
                                text: editedText,
                                sourceApplication: offer.sourceApplication,
                                isEditable: offer.isEditable
                            )
                            model.performSelectionAction(action, offer: updated)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: action.symbolName)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(Color.nAccent)
                                    .frame(width: 16)
                                Text(action.title)
                                    .font(.nSmallMedium)
                                    .foregroundStyle(Color.nTextPrimary)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 32)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Text("Read once through Accessibility. Nothing is sent until you choose an action.")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
            }
        .padding(20)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
        .onAppear {
            if editedText.isEmpty { editedText = offer.text }
        }
        .onTapGesture {}
    }
}

struct SelectionFailureOverlay: View {
    let model: AppModel
    let failure: SelectionFailure

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 9) {
                    Image(systemName: failure.reason == .accessibilityDenied ? "hand.raised" : "text.cursor")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.nWarning)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.nWarning.opacity(0.10)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(failure.title)
                            .font(.nHeadline)
                            .foregroundStyle(Color.nTextPrimary)
                        Text(failure.sourceApplication.map { "Frontmost app: \($0)" } ?? "No source app detected")
                            .font(.nCaptionRegular)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    Spacer()
                    Button {
                        model.dismissSelectionFailure()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderless)
                }

                Text(failure.message)
                    .font(.nSmall)
                    .foregroundStyle(Color.nTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1.5)

                if failure.reason == .accessibilityDenied {
                    Text("macOS requires Accessibility access for NOTCHORA to read the selection. You can grant it now, or use the clipboard instead.")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 7) {
                    if failure.canRequestAccessibility {
                        Button("Grant Accessibility") {
                            model.requestAccessibilityAccess()
                        }
                        .buttonStyle(NButtonStyle(variant: .primary, compact: true))
                        Button("Open Settings") {
                            model.openAccessibilitySettings()
                        }
                        .buttonStyle(NButtonStyle(variant: .secondary, compact: true))
                    }
                    Button("Use Clipboard") {
                        model.dismissSelectionFailure()
                        model.useClipboardAsContext()
                    }
                    .buttonStyle(NButtonStyle(variant: failure.canRequestAccessibility ? .ghost : .primary, compact: true))
                    Spacer()
                    Button("Cancel") {
                        model.dismissSelectionFailure()
                    }
                    .buttonStyle(NButtonStyle(variant: .ghost, compact: true))
                }
            }
        .padding(20)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
        .onTapGesture {}
    }
}
