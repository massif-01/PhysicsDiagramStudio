import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: SettingsStore

    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var temperature = 0.2
    @State private var testStatus: TestStatus = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("模型设置")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("通过 OpenAI-compatible 接口生成 SVG 图示。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Form {
                TextField("Base URL", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $model)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(temperature, format: .number.precision(.fractionLength(2)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $temperature, in: 0...1, step: 0.05)
                }
            }
            .formStyle(.grouped)

            if let message = testStatus.message {
                HStack(spacing: 8) {
                    if testStatus.isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: testStatus.isSuccess ? "checkmark.circle" : "exclamationmark.triangle")
                            .foregroundStyle(testStatus.isSuccess ? .green : .orange)
                    }
                    Text(message)
                        .font(.callout)
                        .lineLimit(2)
                }
            }

            HStack {
                Button("测试连接") {
                    testConnection()
                }
                .disabled(testStatus.isTesting)
                .help("测试连接")

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .help("取消")
                Button("保存") {
                    saveAndDismiss()
                }
                .buttonStyle(.borderedProminent)
                .help("保存")
            }
        }
        .padding(22)
        .frame(width: 520)
        .onAppear(perform: loadDraft)
    }

    private func loadDraft() {
        baseURL = settings.baseURL
        apiKey = settings.apiKey
        model = settings.model
        temperature = settings.temperature
    }

    private func saveAndDismiss() {
        do {
            try settings.save(baseURL: baseURL, model: model, temperature: temperature, apiKey: apiKey)
            dismiss()
        } catch {
            testStatus = .failure(error.localizedDescription)
        }
    }

    private func testConnection() {
        let draftConfig = ProviderConfig(
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            temperature: min(max(temperature, 0), 1)
        )

        guard draftConfig.isUsable else {
            testStatus = .failure(SettingsError.invalidConfiguration.localizedDescription)
            return
        }

        testStatus = .testing
        Task {
            do {
                try await OpenAICompatibleClient(config: draftConfig).testConnection()
                await MainActor.run {
                    testStatus = .success("连接成功。")
                }
            } catch {
                await MainActor.run {
                    testStatus = .failure(error.localizedDescription)
                }
            }
        }
    }
}

private enum TestStatus: Equatable {
    case idle
    case testing
    case success(String)
    case failure(String)

    var isTesting: Bool {
        if case .testing = self { return true }
        return false
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var message: String? {
        switch self {
        case .idle:
            nil
        case .testing:
            "正在测试连接..."
        case .success(let message), .failure(let message):
            message
        }
    }
}
