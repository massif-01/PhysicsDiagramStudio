import Foundation
import Observation

@Observable
final class SettingsStore {
    var baseURL: String
    var model: String
    var temperature: Double
    var apiKey: String

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let keychain: KeychainService

    init(defaults: UserDefaults = .standard, keychain: KeychainService = KeychainService()) {
        self.defaults = defaults
        self.keychain = keychain
        self.baseURL = defaults.string(forKey: DefaultsKey.baseURL) ?? "https://api.openai.com/v1"
        self.model = defaults.string(forKey: DefaultsKey.model) ?? "gpt-4.1"
        let storedTemperature = defaults.object(forKey: DefaultsKey.temperature) as? Double
        self.temperature = storedTemperature ?? 0.2
        self.apiKey = keychain.readAPIKey()
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

        try keychain.saveAPIKey(nextAPIKey)

        self.baseURL = nextBaseURL
        self.model = nextModel
        self.temperature = nextTemperature
        self.apiKey = nextAPIKey

        defaults.set(nextBaseURL, forKey: DefaultsKey.baseURL)
        defaults.set(nextModel, forKey: DefaultsKey.model)
        defaults.set(nextTemperature, forKey: DefaultsKey.temperature)
    }

    var providerConfig: ProviderConfig {
        ProviderConfig(
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
}
