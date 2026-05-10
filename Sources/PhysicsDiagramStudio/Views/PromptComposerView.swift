import SwiftUI

struct PromptComposerView: View {
    @Binding var prompt: String
    var status: GenerationStatus
    var onGenerate: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("物理题目")
                        .font(.headline)
                    Text("输入中文或英文题目，生成可编辑 SVG 与 PNG 预览。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if status.isBusy {
                    Button("取消", action: onCancel)
                        .help("取消")
                } else {
                    Button("生成图示", action: onGenerate)
                        .buttonStyle(.borderedProminent)
                        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .help("生成图示")
                }
            }

            TextEditor(text: $prompt)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .frame(minHeight: 130, idealHeight: 160, maxHeight: 220)

            if let message = status.message {
                HStack(spacing: 8) {
                    if status.isBusy {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(status.isBusy ? .secondary : .primary)
                        .lineLimit(2)
                }
            }
        }
        .padding(18)
    }
}
