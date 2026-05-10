import SwiftUI

struct DetailView: View {
    @Bindable var store: DiagramStore
    @Binding var prompt: String

    var onGenerate: () -> Void
    var onCancel: () -> Void
    var onExport: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PromptComposerView(
                prompt: $prompt,
                status: store.status,
                onGenerate: onGenerate,
                onCancel: onCancel
            )
            Divider()
            PreviewPaneView(store: store, onExport: onExport)
        }
    }
}
