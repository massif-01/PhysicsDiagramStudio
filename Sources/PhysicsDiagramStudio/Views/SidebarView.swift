import SwiftUI

struct SidebarView: View {
    @Bindable var store: DiagramStore
    @State private var recordPendingDeletion: DiagramRecord?

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
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.title)
                                    .lineLimit(1)
                                Text(formatter.string(from: record.createdAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)

                            Button(role: .destructive) {
                                recordPendingDeletion = record
                            } label: {
                                Image(systemName: "trash")
                                    .imageScale(.small)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .help("删除这条历史")
                            .disabled(store.status.isBusy)
                        }
                        .tag(Optional(record.id))
                        .contextMenu {
                            Button(role: .destructive) {
                                recordPendingDeletion = record
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            .disabled(store.status.isBusy)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onDeleteCommand {
            if let selected = store.selectedRecord, !store.status.isBusy {
                recordPendingDeletion = selected
            }
        }
        .confirmationDialog(
            "删除历史图示？",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible,
            presenting: recordPendingDeletion
        ) { record in
            Button("删除", role: .destructive) {
                delete(record)
            }
        } message: { record in
            Text("这会同时删除“\(record.title)”的 SVG、PNG 和 HTML 文件。")
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding {
            recordPendingDeletion != nil
        } set: { isPresented in
            if !isPresented {
                recordPendingDeletion = nil
            }
        }
    }

    private func delete(_ record: DiagramRecord) {
        recordPendingDeletion = nil
        Task {
            do {
                try await store.delete(record)
            } catch {
                store.markFailed("删除历史失败：\(error.localizedDescription)")
            }
        }
    }
}
