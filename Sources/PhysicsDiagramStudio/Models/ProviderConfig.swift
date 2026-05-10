import Foundation

struct ProviderConfig: Equatable {
    var baseURL: String
    var apiKey: String
    var model: String
    var temperature: Double

    var completionsURL: URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let base = URL(string: trimmed),
              let scheme = base.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              base.host != nil else {
            return nil
        }

        let path = base.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("chat/completions") {
            return base
        }
        return base.appendingPathComponent("chat/completions")
    }

    var isUsable: Bool {
        completionsURL != nil
            && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
