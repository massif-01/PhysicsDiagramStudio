import Foundation

struct OpenAICompatibleClient {
    private let config: ProviderConfig
    private let session: URLSession

    init(config: ProviderConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func testConnection() async throws {
        _ = try await send(messages: [
            ChatMessage(role: "system", content: "Reply with exactly OK."),
            ChatMessage(role: "user", content: "OK")
        ])
    }

    func generateDiagram(for problem: String) async throws -> DiagramGenerationResult {
        let content = try await send(messages: [
            ChatMessage(role: "system", content: PhysicsDiagramPrompt.system),
            ChatMessage(role: "user", content: "请根据下面的物理题生成清晰教学图：\n\n\(problem)")
        ])
        return try DiagramResponseParser.parse(content)
    }

    private func send(messages: [ChatMessage]) async throws -> String {
        guard let url = config.completionsURL else {
            throw ClientError.invalidBaseURL
        }
        guard config.isUsable else {
            throw ClientError.missingConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(ChatCompletionsRequest(
            model: config.model,
            messages: messages,
            temperature: config.temperature
        ))

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ClientError.http(statusCode: http.statusCode, body: body)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw ClientError.emptyResponse
        }
        return content
    }
}

private struct ChatCompletionsRequest: Encodable {
    var model: String
    var messages: [ChatMessage]
    var temperature: Double
}

private struct ChatMessage: Codable {
    var role: String
    var content: String
}

private struct ChatCompletionsResponse: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var message: Message
    }

    struct Message: Decodable {
        var content: String
    }
}

enum ClientError: LocalizedError {
    case invalidBaseURL
    case missingConfiguration
    case emptyResponse
    case http(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "Base URL 无效，请检查设置。"
        case .missingConfiguration:
            "请先在设置中填写 Base URL、API Key 和模型。"
        case .emptyResponse:
            "模型返回为空。"
        case .http(let statusCode, let body):
            "请求失败（HTTP \(statusCode)）：\(body.prefix(300))"
        }
    }
}
