import Foundation
import Observation

@MainActor
@Observable
final class DiagramStore {
    var records: [DiagramRecord] = []
    var selectedID: UUID?
    var status: GenerationStatus = .idle

    @ObservationIgnored private let fileManager = FileManager.default
    @ObservationIgnored private let exporter = SVGExportService()
    @ObservationIgnored private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    @ObservationIgnored private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init() {
        load()
    }

    var selectedRecord: DiagramRecord? {
        guard let selectedID else { return nil }
        return records.first { $0.id == selectedID }
    }

    func url(for record: DiagramRecord, kind: ArtifactKind) -> URL {
        switch kind {
        case .svg:
            diagramsDirectory.appendingPathComponent(record.svgFilename)
        case .png:
            diagramsDirectory.appendingPathComponent(record.pngFilename)
        case .html:
            diagramsDirectory.appendingPathComponent(record.htmlFilename)
        }
    }

    func add(prompt: String, result: DiagramGenerationResult, diagnosticID: String? = nil) async throws -> DiagramRecord {
        status = .exporting
        let slug = uniqueSlug(from: result.title)
        let exportStartedAt = Date()
        if let diagnosticID {
            GenerationDiagnostics.log(diagnosticID, "artifact_export_started", fields: [
                "slug": slug,
                "svgChars": String(result.svg.count),
                "title": result.title
            ])
        }
        let artifacts = try await exporter.writeArtifacts(
            svg: result.svg,
            title: result.title,
            slug: slug,
            in: diagramsDirectory,
            diagnosticID: diagnosticID
        )
        if let diagnosticID {
            GenerationDiagnostics.log(diagnosticID, "artifact_export_finished", fields: [
                "elapsedMs": GenerationDiagnostics.milliseconds(since: exportStartedAt),
                "html": artifacts.html.lastPathComponent,
                "png": artifacts.png.lastPathComponent,
                "svg": artifacts.svg.lastPathComponent
            ])
        }

        let record = DiagramRecord(
            title: result.title,
            prompt: prompt,
            slug: slug,
            svgFilename: artifacts.svg.lastPathComponent,
            pngFilename: artifacts.png.lastPathComponent,
            htmlFilename: artifacts.html.lastPathComponent
        )
        records.insert(record, at: 0)
        selectedID = record.id
        let indexStartedAt = Date()
        try saveIndex()
        if let diagnosticID {
            GenerationDiagnostics.log(diagnosticID, "index_saved", fields: [
                "elapsedMs": GenerationDiagnostics.milliseconds(since: indexStartedAt),
                "recordID": record.id.uuidString
            ])
        }
        status = .idle
        return record
    }

    func exportSelected(to destinationDirectory: URL) async throws {
        guard let selectedRecord else { return }
        status = .exporting

        let copies = ArtifactKind.allCases.map { kind in
            let source = url(for: selectedRecord, kind: kind)
            return (source: source, destination: destinationDirectory.appendingPathComponent(source.lastPathComponent))
        }

        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            for copy in copies {
                if FileManager.default.fileExists(atPath: copy.destination.path) {
                    try FileManager.default.removeItem(at: copy.destination)
                }
                try FileManager.default.copyItem(at: copy.source, to: copy.destination)
            }
        }.value

        status = .idle
    }

    func markGenerating() {
        status = .generating
    }

    func markIdle() {
        status = .idle
    }

    func markFailed(_ error: Error) {
        status = .failed(error.localizedDescription)
    }

    func markFailed(_ message: String) {
        status = .failed(message)
    }

    private func load() {
        do {
            try fileManager.createDirectory(at: diagramsDirectory, withIntermediateDirectories: true)
            guard fileManager.fileExists(atPath: indexURL.path) else {
                records = []
                return
            }
            let data = try Data(contentsOf: indexURL)
            records = try jsonDecoder.decode([DiagramRecord].self, from: data)
            selectedID = records.first?.id
        } catch {
            records = []
            status = .failed("读取历史失败：\(error.localizedDescription)")
        }
    }

    private func saveIndex() throws {
        try fileManager.createDirectory(at: diagramsDirectory, withIntermediateDirectories: true)
        let data = try jsonEncoder.encode(records)
        try data.write(to: indexURL, options: .atomic)
    }

    private func uniqueSlug(from title: String) -> String {
        let base = Slug.make(from: title)
        var candidate = base
        var index = 2
        while fileManager.fileExists(atPath: diagramsDirectory.appendingPathComponent("\(candidate).svg").path) {
            candidate = "\(base)-\(index)"
            index += 1
        }
        return candidate
    }

    private var applicationSupportDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PhysicsDiagramStudio", isDirectory: true)
    }

    private var diagramsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Diagrams", isDirectory: true)
    }

    private var indexURL: URL {
        diagramsDirectory.appendingPathComponent("index.json")
    }
}

enum ArtifactKind: CaseIterable {
    case svg
    case png
    case html
}
