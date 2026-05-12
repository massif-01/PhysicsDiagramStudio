import Foundation
import OSLog

enum GenerationDiagnostics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.iay.PhysicsDiagramStudio",
        category: "Generation"
    )
    private static let lock = NSLock()
    private static let maxLogBytes: UInt64 = 4 * 1024 * 1024

    static var logURL: URL {
        applicationSupportDirectory
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("generation.log")
    }

    static func makeRunID() -> String {
        String(UUID().uuidString.prefix(8))
    }

    static func log(_ runID: String, _ event: String, fields: [String: String] = [:]) {
        let line = lineFor(runID: runID, event: event, fields: fields)
        logger.info("\(line, privacy: .public)")
        append(line)
    }

    static func milliseconds(since start: Date) -> String {
        String(Int(Date().timeIntervalSince(start) * 1000))
    }

    static func preview(_ value: String, limit: Int = 240) -> String {
        let compact = value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        let normalized = compact.split(separator: " ").joined(separator: " ")
        return String(normalized.prefix(limit))
    }

    private static func lineFor(runID: String, event: String, fields: [String: String]) -> String {
        var parts = [
            "time=\(ISO8601DateFormatter().string(from: Date()))",
            "run=\(runID)",
            "event=\(event)"
        ]
        for key in fields.keys.sorted() {
            parts.append("\(key)=\(quote(fields[key] ?? ""))")
        }
        return parts.joined(separator: " ")
    }

    private static func quote(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }

        do {
            let directory = logURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try rotateIfNeeded()

            let data = Data((line + "\n").utf8)
            if FileManager.default.fileExists(atPath: logURL.path) {
                let handle = try FileHandle(forWritingTo: logURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                handle.write(data)
            } else {
                try data.write(to: logURL, options: .atomic)
            }
        } catch {
            logger.error("Failed to write generation diagnostic log: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func rotateIfNeeded() throws {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: logURL.path),
              let size = attributes[.size] as? UInt64,
              size > maxLogBytes else {
            return
        }

        let rotated = logURL.deletingPathExtension().appendingPathExtension("previous.log")
        if FileManager.default.fileExists(atPath: rotated.path) {
            try FileManager.default.removeItem(at: rotated)
        }
        try FileManager.default.moveItem(at: logURL, to: rotated)
    }

    private static var applicationSupportDirectory: URL {
        AppStorageLocations.applicationSupportDirectory
    }
}
