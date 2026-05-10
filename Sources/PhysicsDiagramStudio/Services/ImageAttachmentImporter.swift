import AppKit
import Foundation
import UniformTypeIdentifiers

enum ImageAttachmentImporter {
    static func loadFirstImage(from providers: [NSItemProvider]) async throws -> PromptImage? {
        for provider in providers {
            if let image = try await loadImage(from: provider) {
                return image
            }
        }
        return nil
    }

    static func loadFirstImage(from urls: [URL]) async throws -> PromptImage? {
        for url in urls where isLikelyImageURL(url) {
            let data = try Data(contentsOf: url)
            let normalized = try normalizeToPNG(data)
            return PromptImage(
                data: normalized,
                mimeType: "image/png",
                name: url.lastPathComponent.isEmpty ? "拖入图片.png" : url.lastPathComponent,
                source: .droppedFile
            )
        }
        return nil
    }

    private static func loadImage(from provider: NSItemProvider) async throws -> PromptImage? {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let fileImage = try await loadFileImage(from: provider) {
            return fileImage
        }

        for type in [UTType.png, .jpeg, .tiff, .gif, .image] where provider.hasItemConformingToTypeIdentifier(type.identifier) {
            let data = try await provider.loadDataRepresentation(for: type.identifier)
            let normalized = try normalizeToPNG(data)
            return PromptImage(
                data: normalized,
                mimeType: "image/png",
                name: "拖入图片.png",
                source: .droppedFile
            )
        }

        return nil
    }

    private static func loadFileImage(from provider: NSItemProvider) async throws -> PromptImage? {
        let item = try await provider.loadItem(for: UTType.fileURL.identifier)
        let url: URL?
        if let data = item as? Data {
            url = URL(dataRepresentation: data, relativeTo: nil)
        } else if let loadedURL = item as? URL {
            url = loadedURL
        } else if let loadedURL = item as? NSURL {
            url = loadedURL as URL
        } else {
            url = nil
        }

        guard let url, isLikelyImageURL(url) else { return nil }
        let data = try Data(contentsOf: url)
        let normalized = try normalizeToPNG(data)
        return PromptImage(
            data: normalized,
            mimeType: "image/png",
            name: url.lastPathComponent.isEmpty ? "拖入图片.png" : url.lastPathComponent,
            source: .droppedFile
        )
    }

    private static func isLikelyImageURL(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    private static func normalizeToPNG(_ data: Data) throws -> Data {
        guard let image = NSImage(data: data),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ImageAttachmentError.invalidImage
        }
        return pngData
    }
}

private extension NSItemProvider {
    func loadDataRepresentation(for typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: ImageAttachmentError.invalidImage)
                }
            }
        }
    }

    func loadItem(for typeIdentifier: String) async throws -> NSSecureCoding {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let item {
                    continuation.resume(returning: item)
                } else {
                    continuation.resume(throwing: ImageAttachmentError.invalidImage)
                }
            }
        }
    }
}

enum ImageAttachmentError: LocalizedError {
    case invalidImage
    case noImageFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "无法读取图片，请换一张 PNG、JPG 或系统可预览的图片。"
        case .noImageFound:
            "没有找到可用图片，请将图片文件拖入题目输入框。"
        }
    }
}
