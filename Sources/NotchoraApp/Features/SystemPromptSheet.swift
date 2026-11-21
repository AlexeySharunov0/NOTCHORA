import SwiftUI

struct SystemPromptSheet: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.nAccentSoft)
                        .frame(width: 30, height: 30)
                    Image(systemName: "text.badge.star")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.nAccent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("System Prompt")
                        .font(.nHeadline)
                        .foregroundStyle(Color.nTextPrimary)
                    Text("Applies to this conversation only.")
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

            VStack(alignment: .leading, spacing: 9) {
                TextEditor(text: $prompt)
                    .font(.nSmall)
                    .foregroundStyle(Color.nTextPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.nSurfaceSunken.opacity(0.6))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.nHairline, lineWidth: 0.8)
                    }

                if model.settings.defaultSystemPrompt.isEmpty {
                    Text("Leave empty to use no system prompt for this chat.")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                } else {
                    Text("Leave empty to fall back to the default prompt in Settings.")
                        .font(.nCaptionRegular)
                        .foregroundStyle(Color.nTextTertiary)
                }

                Text("System prompts shape tone and behavior. They do not bypass provider safety policies. Content from other apps is still treated as untrusted context.")
                    .font(.nCaptionRegular)
                    .foregroundStyle(Color.nTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)

            HStack {
                Button("Clear") {
                    prompt = ""
                }
                .buttonStyle(NButtonStyle(variant: .ghost))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(NButtonStyle(variant: .ghost))
                Button("Save") {
                    model.updateSystemPrompt(prompt)
                    dismiss()
                }
                .buttonStyle(NButtonStyle(variant: .primary))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Hairline() }
        }
        .frame(width: 500, height: 430)
        .background(Color.nPanelSolid)
        .onAppear {
            prompt = model.currentConversation?.systemPrompt ?? ""
        }
    }
}
