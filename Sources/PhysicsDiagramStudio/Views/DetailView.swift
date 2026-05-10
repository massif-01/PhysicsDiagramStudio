import SwiftUI

struct DetailView: View {
    @Bindable var store: DiagramStore
    @Binding var prompt: String
    @Binding var promptImage: PromptImage?

    var onGenerate: () -> Void
    var onCancel: () -> Void
    var onCaptureScreenshot: () -> Void
    var onDropImages: ([NSItemProvider]) -> Bool
    var onDropImageURLs: ([URL]) -> Bool
    var onExport: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PromptComposerView(
                prompt: $prompt,
                promptImage: $promptImage,
                status: store.status,
                onGenerate: onGenerate,
                onCancel: onCancel,
                onCaptureScreenshot: onCaptureScreenshot,
                onDropImages: onDropImages,
                onDropImageURLs: onDropImageURLs
            )
            Divider()
            PreviewPaneView(store: store, onExport: onExport)
        }
    }
}
