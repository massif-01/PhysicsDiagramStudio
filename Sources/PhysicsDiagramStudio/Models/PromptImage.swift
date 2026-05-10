import Foundation

struct PromptImage: Equatable, Identifiable {
    enum Source: Equatable {
        case screenshot
        case droppedFile
    }

    let id: UUID
    var data: Data
    var mimeType: String
    var name: String
    var source: Source

    init(
        id: UUID = UUID(),
        data: Data,
        mimeType: String,
        name: String,
        source: Source
    ) {
        self.id = id
        self.data = data
        self.mimeType = mimeType
        self.name = name
        self.source = source
    }

    var dataURL: String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}
