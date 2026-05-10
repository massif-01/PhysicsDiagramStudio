import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: DiagramStore
    @Bindable var settings: SettingsStore

    @State private var prompt = ""
    @State private var promptImage: PromptImage?
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
                promptImage: $promptImage,
                onGenerate: generate,
                onCancel: cancelGeneration,
                onCaptureScreenshot: captureScreenshot,
                onDropImages: importDroppedImages,
                onDropImageURLs: importDroppedImageURLs,
                onExport: exportSelected
            )
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    prompt = ""
                    promptImage = nil
                    store.selectedID = nil
                    store.markIdle()
                } label: {
                    Label("新建", systemImage: "square.and.pencil")
                }
                .help("新建")

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
                promptImage = nil
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
        let image = promptImage
        guard !problem.isEmpty || image != nil else { return }
        let diagnosticID = GenerationDiagnostics.makeRunID()
        let runStartedAt = Date()
        GenerationDiagnostics.log(diagnosticID, "ui_generate_clicked", fields: [
            "hasImage": image == nil ? "false" : "true",
            "imageBytes": image.map { String($0.data.count) } ?? "0",
            "promptChars": String(problem.count)
        ])
        guard settings.providerConfig.isUsable else {
            GenerationDiagnostics.log(diagnosticID, "generation_blocked_missing_configuration")
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
                let result = try await client.generateDiagram(for: problem, image: image, diagnosticID: diagnosticID)
                GenerationDiagnostics.log(diagnosticID, "client_result_ready", fields: [
                    "svgChars": String(result.svg.count),
                    "title": result.title,
                    "totalElapsedMs": GenerationDiagnostics.milliseconds(since: runStartedAt)
                ])
                try Task.checkCancellation()
                let record = try await store.add(
                    prompt: problem.isEmpty ? "图片输入" : problem,
                    result: result,
                    diagnosticID: diagnosticID
                )
                GenerationDiagnostics.log(diagnosticID, "generation_completed", fields: [
                    "recordID": record.id.uuidString,
                    "slug": record.slug,
                    "totalElapsedMs": GenerationDiagnostics.milliseconds(since: runStartedAt)
                ])
            } catch is CancellationError {
                GenerationDiagnostics.log(diagnosticID, "generation_cancelled", fields: [
                    "totalElapsedMs": GenerationDiagnostics.milliseconds(since: runStartedAt)
                ])
                await MainActor.run {
                    store.markIdle()
                }
            } catch {
                GenerationDiagnostics.log(diagnosticID, "generation_failed", fields: [
                    "error": error.localizedDescription,
                    "totalElapsedMs": GenerationDiagnostics.milliseconds(since: runStartedAt)
                ])
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

    private func captureScreenshot() {
        guard !showingSettings, !store.status.isBusy else { return }
        Task {
            do {
                let image = try await ScreenshotCaptureService.captureInteractive()
                await MainActor.run {
                    promptImage = image
                    store.markIdle()
                }
            } catch ScreenshotCaptureError.cancelled {
                return
            } catch {
                await MainActor.run {
                    store.markFailed(error)
                }
            }
        }
    }

    private func importDroppedImages(_ providers: [NSItemProvider]) -> Bool {
        guard !store.status.isBusy else { return false }
        Task {
            do {
                guard let image = try await ImageAttachmentImporter.loadFirstImage(from: providers) else {
                    throw ImageAttachmentError.noImageFound
                }
                await MainActor.run {
                    promptImage = image
                    store.markIdle()
                }
            } catch {
                await MainActor.run {
                    store.markFailed(error)
                }
            }
        }
        return true
    }

    private func importDroppedImageURLs(_ urls: [URL]) -> Bool {
        guard !store.status.isBusy else { return false }
        Task {
            do {
                guard let image = try await ImageAttachmentImporter.loadFirstImage(from: urls) else {
                    throw ImageAttachmentError.noImageFound
                }
                await MainActor.run {
                    promptImage = image
                    store.markIdle()
                }
            } catch {
                await MainActor.run {
                    store.markFailed(error)
                }
            }
        }
        return true
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
