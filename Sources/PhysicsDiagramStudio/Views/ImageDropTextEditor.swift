import AppKit
import SwiftUI

struct ImageDropTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isDropTargeted: Bool

    var font: NSFont = .preferredFont(forTextStyle: .body)
    var onDropImageURLs: ([URL]) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isDropTargeted: $isDropTargeted, onDropImageURLs: onDropImageURLs)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = DroppableTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = font
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.registerForDraggedTypes([.fileURL, .URL, .png, .tiff])
        textView.onImageDragStateChange = { targeted in
            context.coordinator.isDropTargeted.wrappedValue = targeted
        }
        textView.onDropImageURLs = onDropImageURLs

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        context.coordinator.onDropImageURLs = onDropImageURLs
        textView.onDropImageURLs = onDropImageURLs
        textView.font = font
        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var isDropTargeted: Binding<Bool>
        var onDropImageURLs: ([URL]) -> Bool
        weak var textView: DroppableTextView?

        init(
            text: Binding<String>,
            isDropTargeted: Binding<Bool>,
            onDropImageURLs: @escaping ([URL]) -> Bool
        ) {
            self.text = text
            self.isDropTargeted = isDropTargeted
            self.onDropImageURLs = onDropImageURLs
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

final class DroppableTextView: NSTextView {
    var onImageDragStateChange: ((Bool) -> Void)?
    var onDropImageURLs: (([URL]) -> Bool)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard imageURLs(from: sender.draggingPasteboard).isEmpty == false else {
            return super.draggingEntered(sender)
        }
        onImageDragStateChange?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard imageURLs(from: sender.draggingPasteboard).isEmpty == false else {
            return super.draggingUpdated(sender)
        }
        onImageDragStateChange?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onImageDragStateChange?(false)
        super.draggingExited(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = imageURLs(from: sender.draggingPasteboard)
        guard urls.isEmpty == false else {
            return super.performDragOperation(sender)
        }
        onImageDragStateChange?(false)
        return onDropImageURLs?(urls) ?? false
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onImageDragStateChange?(false)
        super.concludeDragOperation(sender)
    }

    private func imageURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) ?? []
        let urls = objects.compactMap { object -> URL? in
            if let url = object as? URL {
                return url
            }
            if let url = object as? NSURL {
                return url as URL
            }
            return nil
        }
        return urls.filter { url in
            guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
                return NSImage(contentsOf: url) != nil
            }
            return type.conforms(to: .image)
        }
    }
}
