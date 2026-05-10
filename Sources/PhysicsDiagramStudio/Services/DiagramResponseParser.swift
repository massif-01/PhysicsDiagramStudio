import Foundation

enum DiagramResponseParser {
    static func parse(_ content: String) throws -> DiagramGenerationResult {
        let cleaned = content
            .replacingOccurrences(of: "```svg", with: "")
            .replacingOccurrences(of: "```xml", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let svgStart = cleaned.range(of: "<svg"),
              let svgEnd = cleaned.range(of: "</svg>", options: .backwards) else {
            throw ParserError.missingSVG
        }

        let svg = String(cleaned[svgStart.lowerBound..<svgEnd.upperBound])
        let title = extractTag("title", from: cleaned) ?? "物理图示"
        guard svg.contains("</svg>") else {
            throw ParserError.missingSVG
        }
        return DiagramGenerationResult(title: title, svg: svg)
    }

    private static func extractTag(_ tag: String, from content: String) -> String? {
        guard let start = content.range(of: "<\(tag)>"),
              let end = content.range(of: "</\(tag)>", options: .caseInsensitive),
              start.upperBound <= end.lowerBound else {
            return nil
        }
        return String(content[start.upperBound..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ParserError: LocalizedError {
    case missingSVG

    var errorDescription: String? {
        switch self {
        case .missingSVG:
            "模型响应中没有找到完整 SVG。"
        }
    }
}
