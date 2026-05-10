import Foundation

struct SVGExportService {
    func writeArtifacts(svg: String, title: String, slug: String, in directory: URL) async throws -> ArtifactURLs {
        try await Task.detached(priority: .userInitiated) {
            try writeArtifactsSync(svg: svg, title: title, slug: slug, in: directory)
        }.value
    }

    private func writeArtifactsSync(svg: String, title: String, slug: String, in directory: URL) throws -> ArtifactURLs {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let svgURL = directory.appendingPathComponent("\(slug).svg")
        let pngURL = directory.appendingPathComponent("\(slug).png")
        let htmlURL = directory.appendingPathComponent("\(slug).html")

        try svg.write(to: svgURL, atomically: true, encoding: .utf8)
        try renderPNG(svgURL: svgURL, pngURL: pngURL)
        try html(title: title, svgFilename: svgURL.lastPathComponent)
            .write(to: htmlURL, atomically: true, encoding: .utf8)

        return ArtifactURLs(svg: svgURL, png: pngURL, html: htmlURL)
    }

    private func renderPNG(svgURL: URL, pngURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = [
            "-s", "format", "png",
            svgURL.path,
            "--out",
            pngURL.path
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ExportError.pngRenderFailed
        }
    }

    private func html(title: String, svgFilename: String) -> String {
        """
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(title.escapedHTML)</title>
          <style>
            body {
              margin: 0;
              min-height: 100vh;
              display: grid;
              place-items: center;
              background: #f6f7f9;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            }
            .figure {
              background: #fff;
              padding: 24px;
              border: 1px solid #e5e7eb;
              border-radius: 8px;
              box-shadow: 0 12px 30px rgba(0, 0, 0, 0.08);
            }
            img {
              display: block;
              max-width: min(1280px, calc(100vw - 64px));
              height: auto;
            }
          </style>
        </head>
        <body>
          <div class="figure">
            <img src="\(svgFilename.escapedHTML)" alt="\(title.escapedHTML)">
          </div>
        </body>
        </html>
        """
    }
}

struct ArtifactURLs {
    var svg: URL
    var png: URL
    var html: URL
}

enum ExportError: LocalizedError {
    case pngRenderFailed

    var errorDescription: String? {
        switch self {
        case .pngRenderFailed:
            "PNG 渲染失败。"
        }
    }
}
