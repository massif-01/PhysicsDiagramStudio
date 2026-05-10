import Foundation
import Observation

@Observable
final class SettingsStore {
    var baseURL: String
    var model: String
    var temperature: Double
    var apiKey: String

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.baseURL = defaults.string(forKey: DefaultsKey.baseURL) ?? "https://api.openai.com/v1"
        self.model = defaults.string(forKey: DefaultsKey.model) ?? "gpt-4.1"
        let storedTemperature = defaults.object(forKey: DefaultsKey.temperature) as? Double
        self.temperature = storedTemperature ?? 0.7
        self.apiKey = defaults.string(forKey: DefaultsKey.apiKey) ?? ""
    }

    func save(baseURL: String, model: String, temperature: Double, apiKey: String) throws {
        let nextBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextTemperature = min(max(temperature, 0), 1)
        let nextConfig = ProviderConfig(
            baseURL: nextBaseURL,
            apiKey: nextAPIKey,
            model: nextModel,
            temperature: nextTemperature
        )

        guard nextConfig.isUsable else {
            throw SettingsError.invalidConfiguration
        }

        self.baseURL = nextBaseURL
        self.model = nextModel
        self.temperature = nextTemperature
        self.apiKey = nextAPIKey

        defaults.set(nextBaseURL, forKey: DefaultsKey.baseURL)
        defaults.set(nextModel, forKey: DefaultsKey.model)
        defaults.set(nextTemperature, forKey: DefaultsKey.temperature)
        defaults.set(nextAPIKey, forKey: DefaultsKey.apiKey)
    }

    var providerConfig: ProviderConfig {
        return ProviderConfig(
            baseURL: baseURL,
            apiKey: apiKey,
            model: model,
            temperature: temperature
        )
    }
}

enum SettingsError: LocalizedError {
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "请填写有效的 Base URL、API Key 和模型。Base URL 需要包含 http 或 https。"
        }
    }
}

private enum DefaultsKey {
    static let baseURL = "provider.baseURL"
    static let model = "provider.model"
    static let temperature = "provider.temperature"
    static let apiKey = "provider.apiKey"
}
