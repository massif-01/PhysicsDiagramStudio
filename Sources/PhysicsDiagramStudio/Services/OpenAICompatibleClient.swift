import Foundation

struct OpenAICompatibleClient {
    private let config: ProviderConfig
    private let session: URLSession
    private let timeoutSeconds: Int

    init(config: ProviderConfig, session: URLSession = .openAICompatibleGeneration, timeoutSeconds: Int = 600) {
        self.config = config
        self.session = session
        self.timeoutSeconds = timeoutSeconds
    }

    func testConnection() async throws {
        let diagnosticID = GenerationDiagnostics.makeRunID()
        GenerationDiagnostics.log(diagnosticID, "connection_test_started", fields: [
            "model": config.model,
            "temperature": String(format: "%.2f", config.temperature)
        ])
        _ = try await send(messages: [
            ChatMessage(role: "system", content: "Reply with exactly OK."),
            ChatMessage(role: "user", content: "OK")
        ], maxTokens: 32, allowsEmptyContent: true, diagnosticID: diagnosticID, stage: "connection_test")
        GenerationDiagnostics.log(diagnosticID, "connection_test_finished")
    }

    func generateDiagram(
        for problem: String,
        image: PromptImage? = nil,
        diagnosticID: String = GenerationDiagnostics.makeRunID()
    ) async throws -> DiagramGenerationResult {
        let generationStartedAt = Date()
        GenerationDiagnostics.log(diagnosticID, "generation_request_prepared", fields: [
            "hasImage": image == nil ? "false" : "true",
            "imageBytes": image.map { String($0.data.count) } ?? "0",
            "imageMime": image?.mimeType ?? "",
            "model": config.model,
            "promptChars": String(problem.count),
            "temperature": String(format: "%.2f", config.temperature)
        ])

        let trimmedProblem = problem.trimmingCharacters(in: .whitespacesAndNewlines)
        let problemText = trimmedProblem.isEmpty ? "请先识别图片中的物理题，并生成清晰教学图。" : trimmedProblem
        let userText = """
        请根据下面的物理题生成清晰教学图。如果附带了图片，请先识别图片中的题目、图像和标注信息，再结合文字输入生成结果：

        \(problemText)
        """
        let userMessage: ChatMessage
        if let image {
            userMessage = ChatMessage(role: "user", content: [
                .text(userText),
                .imageURL(image.dataURL)
            ])
        } else {
            userMessage = ChatMessage(role: "user", content: userText)
        }

        let content = try await send(messages: [
            ChatMessage(role: "system", content: PhysicsDiagramPrompt.system),
            userMessage
        ], diagnosticID: diagnosticID, stage: "primary")
        GenerationDiagnostics.log(diagnosticID, "primary_content_ready", fields: [
            "contentChars": String(content.count),
            "containsSVG": content.contains("<svg") ? "true" : "false",
            "totalElapsedMs": GenerationDiagnostics.milliseconds(since: generationStartedAt)
        ])

        let parseStartedAt = Date()
        do {
            let result = try DiagramResponseParser.parse(content)
            GenerationDiagnostics.log(diagnosticID, "primary_svg_parsed", fields: [
                "parseElapsedMs": GenerationDiagnostics.milliseconds(since: parseStartedAt),
                "svgChars": String(result.svg.count),
                "title": result.title,
                "totalElapsedMs": GenerationDiagnostics.milliseconds(since: generationStartedAt)
            ])
            return result
        } catch ParserError.missingSVG {
            GenerationDiagnostics.log(diagnosticID, "primary_svg_missing_repair_started", fields: [
                "contentPreview": GenerationDiagnostics.preview(content),
                "totalElapsedMs": GenerationDiagnostics.milliseconds(since: generationStartedAt)
            ])
            let repairStartedAt = Date()
            let repaired = try await repairDiagramResponse(content, diagnosticID: diagnosticID)
            GenerationDiagnostics.log(diagnosticID, "repair_content_ready", fields: [
                "contentChars": String(repaired.count),
                "containsSVG": repaired.contains("<svg") ? "true" : "false",
                "repairElapsedMs": GenerationDiagnostics.milliseconds(since: repairStartedAt),
                "totalElapsedMs": GenerationDiagnostics.milliseconds(since: generationStartedAt)
            ])

            let repairParseStartedAt = Date()
            let result = try DiagramResponseParser.parse(repaired)
            GenerationDiagnostics.log(diagnosticID, "repair_svg_parsed", fields: [
                "parseElapsedMs": GenerationDiagnostics.milliseconds(since: repairParseStartedAt),
                "svgChars": String(result.svg.count),
                "title": result.title,
                "totalElapsedMs": GenerationDiagnostics.milliseconds(since: generationStartedAt)
            ])
            return result
        }
    }

    private func repairDiagramResponse(_ invalidContent: String, diagnosticID: String) async throws -> String {
        let repairPrompt = """
        下面是一次不合格的模型输出。请基于其中能识别到的题目、场景或说明，重新输出一个完整 SVG 教学图。

        强制要求：
        1. 只能输出 <title>...</title> 和完整 <svg ...>...</svg>。
        2. 不能输出 Markdown、解释、道歉、分析过程或代码围栏。
        3. 如果原输出没有足够信息，就画一个通用的物理题示意图占位，但仍必须返回完整 SVG。

        不合格输出：
        \(invalidContent.prefix(4000))
        """

        return try await send(messages: [
            ChatMessage(role: "system", content: PhysicsDiagramPrompt.system),
            ChatMessage(role: "user", content: repairPrompt)
        ], diagnosticID: diagnosticID, stage: "repair")
    }

    private func send(
        messages: [ChatMessage],
        maxTokens: Int? = nil,
        allowsEmptyContent: Bool = false,
        diagnosticID: String,
        stage: String
    ) async throws -> String {
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
        let requestBody = try JSONEncoder().encode(ChatCompletionsRequest(
            model: config.model,
            messages: messages,
            temperature: config.temperature,
            maxTokens: maxTokens,
            maxCompletionTokens: nil
        ))
        request.httpBody = requestBody

        GenerationDiagnostics.log(diagnosticID, "\(stage)_http_request_started", fields: [
            "bodyBytes": String(requestBody.count),
            "host": url.host ?? "",
            "maxTokens": maxTokens.map(String.init) ?? "",
            "messageCount": String(messages.count),
            "path": url.path
        ])

        var data: Data
        var response: URLResponse
        let requestStartedAt = Date()
        do {
            (data, response) = try await perform(request)
        } catch {
            GenerationDiagnostics.log(diagnosticID, "\(stage)_http_request_failed", fields: [
                "elapsedMs": GenerationDiagnostics.milliseconds(since: requestStartedAt),
                "error": error.localizedDescription
            ])
            throw error
        }
        logHTTPResponse(diagnosticID: diagnosticID, stage: stage, response: response, data: data, startedAt: requestStartedAt)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            if shouldRetryWithMaxCompletionTokens(statusCode: http.statusCode, body: body, maxTokens: maxTokens) {
                GenerationDiagnostics.log(diagnosticID, "\(stage)_retry_max_completion_tokens", fields: [
                    "status": String(http.statusCode),
                    "bodyPreview": GenerationDiagnostics.preview(body)
                ])
                let retryBody = try JSONEncoder().encode(ChatCompletionsRequest(
                    model: config.model,
                    messages: messages,
                    temperature: config.temperature,
                    maxTokens: nil,
                    maxCompletionTokens: maxTokens
                ))
                request.httpBody = retryBody
                GenerationDiagnostics.log(diagnosticID, "\(stage)_retry_http_request_started", fields: [
                    "bodyBytes": String(retryBody.count),
                    "host": url.host ?? "",
                    "maxCompletionTokens": maxTokens.map(String.init) ?? "",
                    "messageCount": String(messages.count),
                    "path": url.path
                ])
                let retryStartedAt = Date()
                do {
                    (data, response) = try await perform(request)
                } catch {
                    GenerationDiagnostics.log(diagnosticID, "\(stage)_retry_http_request_failed", fields: [
                        "elapsedMs": GenerationDiagnostics.milliseconds(since: retryStartedAt),
                        "error": error.localizedDescription
                    ])
                    throw error
                }
                logHTTPResponse(diagnosticID: diagnosticID, stage: "\(stage)_retry", response: response, data: data, startedAt: retryStartedAt)
                if let retryHTTP = response as? HTTPURLResponse, !(200..<300).contains(retryHTTP.statusCode) {
                    let retryBody = String(data: data, encoding: .utf8) ?? ""
                    GenerationDiagnostics.log(diagnosticID, "\(stage)_retry_http_error", fields: [
                        "status": String(retryHTTP.statusCode),
                        "bodyPreview": GenerationDiagnostics.preview(retryBody)
                    ])
                    throw ClientError.http(statusCode: retryHTTP.statusCode, body: retryBody)
                }
            } else {
                GenerationDiagnostics.log(diagnosticID, "\(stage)_http_error", fields: [
                    "status": String(http.statusCode),
                    "bodyPreview": GenerationDiagnostics.preview(body)
                ])
                throw ClientError.http(statusCode: http.statusCode, body: body)
            }
        }

        let decodeStartedAt = Date()
        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        GenerationDiagnostics.log(diagnosticID, "\(stage)_json_decoded", fields: [
            "choiceCount": String(decoded.choices.count),
            "decodeElapsedMs": GenerationDiagnostics.milliseconds(since: decodeStartedAt)
        ])
        guard let content = decoded.choices.first?.message.content else {
            GenerationDiagnostics.log(diagnosticID, "\(stage)_empty_response", fields: [
                "reason": "missing message content"
            ])
            throw ClientError.emptyResponse
        }
        guard !content.isEmpty || allowsEmptyContent else {
            GenerationDiagnostics.log(diagnosticID, "\(stage)_empty_response", fields: [
                "reason": "empty content"
            ])
            throw ClientError.emptyResponse
        }
        GenerationDiagnostics.log(diagnosticID, "\(stage)_content_extracted", fields: [
            "contentChars": String(content.count),
            "contentPreview": GenerationDiagnostics.preview(content)
        ])
        return content
    }

    private func logHTTPResponse(
        diagnosticID: String,
        stage: String,
        response: URLResponse,
        data: Data,
        startedAt: Date
    ) {
        let status = (response as? HTTPURLResponse).map { String($0.statusCode) } ?? ""
        GenerationDiagnostics.log(diagnosticID, "\(stage)_http_response_received", fields: [
            "bytes": String(data.count),
            "elapsedMs": GenerationDiagnostics.milliseconds(since: startedAt),
            "status": status
        ])
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ClientError.timeout(seconds: timeoutSeconds)
        }
    }

    private func shouldRetryWithMaxCompletionTokens(statusCode: Int, body: String, maxTokens: Int?) -> Bool {
        guard statusCode == 400, maxTokens != nil else { return false }
        let lowercasedBody = body.lowercased()
        return lowercasedBody.contains("max_tokens")
            && lowercasedBody.contains("max_completion_tokens")
    }
}

private struct ChatCompletionsRequest: Encodable {
    var model: String
    var messages: [ChatMessage]
    var temperature: Double
    var maxTokens: Int?
    var maxCompletionTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case maxCompletionTokens = "max_completion_tokens"
    }
}

private struct ChatMessage: Encodable {
    var role: String
    var content: ChatContent

    init(role: String, content: String) {
        self.role = role
        self.content = .text(content)
    }

    init(role: String, content: [ChatContentPart]) {
        self.role = role
        self.content = .parts(content)
    }
}

private enum ChatContent: Encodable {
    case text(String)
    case parts([ChatContentPart])

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .parts(let parts):
            var container = encoder.singleValueContainer()
            try container.encode(parts)
        }
    }
}

private struct ChatContentPart: Encodable {
    var type: String
    var text: String?
    var imageURL: ImageURL?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    static func text(_ value: String) -> ChatContentPart {
        ChatContentPart(type: "text", text: value, imageURL: nil)
    }

    static func imageURL(_ dataURL: String) -> ChatContentPart {
        ChatContentPart(type: "image_url", text: nil, imageURL: ImageURL(url: dataURL, detail: "auto"))
    }
}

private struct ImageURL: Encodable {
    var url: String
    var detail: String
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
    case timeout(seconds: Int)
    case http(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "Base URL 无效，请检查设置。"
        case .missingConfiguration:
            "请先在设置中填写 Base URL、API Key 和模型。"
        case .emptyResponse:
            "模型返回为空。"
        case .timeout(let seconds):
            "请求超时：三方 API 没有在 \(seconds) 秒内返回响应。请检查 Base URL、代理、模型名，或稍后重试。"
        case .http(let statusCode, let body):
            "请求失败（HTTP \(statusCode)）：\(body.prefix(300))"
        }
    }
}

extension URLSession {
    static let openAICompatibleGeneration: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 600
        configuration.timeoutIntervalForResource = 900
        return URLSession(configuration: configuration)
    }()

    static let openAICompatibleConnectionTest: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()
}
