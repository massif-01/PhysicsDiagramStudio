import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: SettingsStore

    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var temperature = 0.7
    @State private var testStatus: TestStatus = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("模型设置")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("推荐使用GPT5.5或有多模态能力的模型")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 0) {
                SettingsFieldRow("Base URL") {
                    TextField("https://api.openai.com/v1", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                }

                SettingsDivider()

                SettingsFieldRow("API Key") {
                    SecureField("sk-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }

                SettingsDivider()

                SettingsFieldRow("Model") {
                    TextField("gpt-5.5", text: $model)
                        .textFieldStyle(.roundedBorder)
                }

                SettingsDivider()

                SettingsFieldRow("Temperature") {
                    VStack(spacing: 6) {
                        HStack {
                            Spacer()
                            Text(temperature, format: .number.precision(.fractionLength(2)))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $temperature, in: 0...1, step: 0.05)
                    }
                }
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

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

            ZStack {
                HStack {
                    Button("测试连接") {
                        testConnection()
                    }
                    .disabled(testStatus.isTesting)
                    .help("测试连接")

                    Spacer()
                }

                HStack(spacing: 12) {
                    Spacer()

                    Button("取消") {
                        dismiss()
                    }
                    .help("取消")
                    .fixedSize()

                    Button("保存") {
                        saveAndDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .help("保存")
                    .fixedSize()
                }
            }
            .frame(width: 476)
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
                try await OpenAICompatibleClient(
                    config: draftConfig,
                    session: .openAICompatibleConnectionTest,
                    timeoutSeconds: 30
                ).testConnection()
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

private struct SettingsFieldRow<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Text(title)
                .frame(width: 116, alignment: .leading)
            content
        }
        .frame(minHeight: 46)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 134)
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
