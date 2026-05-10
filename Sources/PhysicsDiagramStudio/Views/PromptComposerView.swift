import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PromptComposerView: View {
    @Binding var prompt: String
    @Binding var promptImage: PromptImage?
    var status: GenerationStatus
    var onGenerate: () -> Void
    var onCancel: () -> Void
    var onCaptureScreenshot: () -> Void
    var onDropImages: ([NSItemProvider]) -> Bool
    var onDropImageURLs: ([URL]) -> Bool

    @State private var isDropTargeted = false

    private var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || promptImage != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("题目输入")
                        .font(.headline)
                }
                Spacer()
                if status.isBusy {
                    Button("取消", action: onCancel)
                        .help("取消")
                } else {
                    Button("生成图示", action: onGenerate)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(!canGenerate)
                        .help("生成图示")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    Label("按control+P打开截图", systemImage: "camera.viewfinder")
                    Label("可以将图片拖入题目输入框", systemImage: "photo.on.rectangle.angled")
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let promptImage {
                    AttachedPromptImageView(image: promptImage) {
                        self.promptImage = nil
                    }
                }

                ImageDropTextEditor(
                    text: $prompt,
                    isDropTargeted: $isDropTargeted,
                    onDropImageURLs: onDropImageURLs
                )
                    .frame(minHeight: 110, idealHeight: 140, maxHeight: 190)
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
            }
            .onDrop(
                of: [UTType.fileURL.identifier, UTType.image.identifier, UTType.png.identifier, UTType.jpeg.identifier],
                isTargeted: $isDropTargeted,
                perform: onDropImages
            )
            .background {
                KeyboardShortcutMonitor(key: "p", modifiers: [.control], action: onCaptureScreenshot)
                    .frame(width: 0, height: 0)
            }

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

private struct AttachedPromptImageView: View {
    var image: PromptImage
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: 48, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.quaternary, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(image.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\(sourceText)已附加给模型 · \(image.displaySize)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("移除图片")
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let nsImage = NSImage(data: image.data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }

    private var sourceText: String {
        switch image.source {
        case .screenshot:
            "截图"
        case .droppedFile:
            "图片"
        }
    }
}
