import AppKit
import SwiftUI

struct PreviewPaneView: View {
    @Bindable var store: DiagramStore
    var onExport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.selectedRecord?.title ?? "图示")
                        .font(.headline)
                }
                Spacer()
                if let record = store.selectedRecord {
                    Button {
                        NSWorkspace.shared.open(store.url(for: record, kind: .html))
                    } label: {
                        Label("打开 HTML", systemImage: "safari")
                    }
                    .help("打开 HTML")

                    Button(action: onExport) {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                    .help("导出")
                }
            }

            Group {
                if let record = store.selectedRecord,
                   let image = NSImage(contentsOf: store.url(for: record, kind: .png)) {
                    GeometryReader { proxy in
                        ScrollView([.horizontal, .vertical]) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    minWidth: proxy.size.width,
                                    minHeight: proxy.size.height
                                )
                                .padding(20)
                        }
                    }
                } else {
                    ContentUnavailableView("等待生成", systemImage: "point.3.connected.trianglepath.dotted", description: Text("输入题目并点击生成图示。"))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(18)
    }
}
