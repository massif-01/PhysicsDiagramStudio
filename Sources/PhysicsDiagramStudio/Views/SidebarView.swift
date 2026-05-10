import SwiftUI

struct SidebarView: View {
    @Bindable var store: DiagramStore

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        List(selection: $store.selectedID) {
            Section("历史图示") {
                if store.records.isEmpty {
                    ContentUnavailableView("暂无历史", systemImage: "doc.richtext", description: Text("生成后的图示会保存在这里。"))
                } else {
                    ForEach(store.records) { record in
                        HStack(spacing: 10) {
                            Image(systemName: "figure.mind.and.body")
                                .foregroundStyle(.secondary)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.title)
                                    .lineLimit(1)
                                Text(formatter.string(from: record.createdAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .tag(Optional(record.id))
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}
