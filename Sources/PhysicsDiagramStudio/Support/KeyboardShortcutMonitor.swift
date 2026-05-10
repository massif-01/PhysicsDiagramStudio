import AppKit
import SwiftUI

struct KeyboardShortcutMonitor: NSViewRepresentable {
    var key: String
    var modifiers: NSEvent.ModifierFlags
    var action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(key: key, modifiers: modifiers, action: action)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.install()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.key = key
        context.coordinator.modifiers = modifiers
        context.coordinator.action = action
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        var key: String
        var modifiers: NSEvent.ModifierFlags
        var action: () -> Void
        private var monitor: Any?

        init(key: String, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
            self.key = key
            self.modifiers = modifiers
            self.action = action
        }

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.matches(event) else { return event }
                self.action()
                return nil
            }
        }

        func uninstall() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        private func matches(_ event: NSEvent) -> Bool {
            guard !event.isARepeat,
                  event.charactersIgnoringModifiers?.lowercased() == key.lowercased() else {
                return false
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let expected = modifiers.intersection(.deviceIndependentFlagsMask)
            guard flags.isSuperset(of: expected) else { return false }
            return !flags.contains(.command) && !flags.contains(.option)
        }
    }
}
