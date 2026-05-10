import Foundation

enum ScreenshotCaptureService {
    static func captureInteractive() async throws -> PromptImage {
        try await Task.detached(priority: .userInitiated) {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("PhysicsDiagramStudio-\(UUID().uuidString)")
                .appendingPathExtension("png")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-x", url.path]

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0,
                  FileManager.default.fileExists(atPath: url.path) else {
                throw ScreenshotCaptureError.cancelled
            }

            let data = try Data(contentsOf: url)
            try? FileManager.default.removeItem(at: url)
            guard !data.isEmpty else {
                throw ScreenshotCaptureError.cancelled
            }

            return PromptImage(
                data: data,
                mimeType: "image/png",
                name: "截图.png",
                source: .screenshot
            )
        }.value
    }
}

enum ScreenshotCaptureError: LocalizedError {
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "截图已取消。"
        }
    }
}
