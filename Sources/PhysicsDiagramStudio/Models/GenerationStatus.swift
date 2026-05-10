import Foundation

enum GenerationStatus: Equatable {
    case idle
    case generating
    case exporting
    case failed(String)
}

extension GenerationStatus {
    var isBusy: Bool {
        switch self {
        case .generating, .exporting:
            true
        case .idle, .failed:
            false
        }
    }

    var message: String? {
        switch self {
        case .idle:
            nil
        case .generating:
            "正在生成 SVG 图示..."
        case .exporting:
            "正在导出文件..."
        case .failed(let message):
            message
        }
    }
}
