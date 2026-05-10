import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: DiagramStore
    @Bindable var settings: SettingsStore

    @State private var prompt = ""
    @State private var showingSettings = false
    @State private var generationTask: Task<Void, Never>?

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            DetailView(
                store: store,
                prompt: $prompt,
                onGenerate: generate,
                onCancel: cancelGeneration,
                onExport: exportSelected
            )
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    prompt = ""
                    store.selectedID = nil
                    store.markIdle()
                } label: {
                    Label("新建", systemImage: "square.and.pencil")
                }
                .help("新建")

                Button {
                    generate()
                } label: {
                    Label("生成", systemImage: "sparkles")
                }
                .help("生成")
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.status.isBusy)

                Button {
                    exportSelected()
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .help("导出")
                .disabled(store.selectedRecord == nil || store.status.isBusy)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
                .help("设置")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings)
        }
        .onChange(of: store.selectedID) { _, _ in
            if let selected = store.selectedRecord {
                prompt = selected.prompt
            }
        }
        .onAppear {
            if prompt.isEmpty, let selected = store.selectedRecord {
                prompt = selected.prompt
            }
        }
    }

    private func generate() {
        let problem = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !problem.isEmpty else { return }
        guard settings.providerConfig.isUsable else {
            store.markFailed("请先在设置中填写 Base URL、API Key 和模型。")
            showingSettings = true
            return
        }

        generationTask?.cancel()
        generationTask = Task {
            await MainActor.run {
                store.markGenerating()
            }
            do {
                let client = OpenAICompatibleClient(config: settings.providerConfig)
                let result = try await client.generateDiagram(for: problem)
                try Task.checkCancellation()
                _ = try await store.add(prompt: problem, result: result)
            } catch is CancellationError {
                await MainActor.run {
                    store.markIdle()
                }
            } catch {
                await MainActor.run {
                    store.markFailed(error)
                }
            }
        }
    }

    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        store.markIdle()
    }

    private func exportSelected() {
        let panel = NSOpenPanel()
        panel.title = "选择导出文件夹"
        panel.prompt = "导出"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                try await store.exportSelected(to: url)
            } catch {
                store.markFailed(error)
            }
        }
    }
}
