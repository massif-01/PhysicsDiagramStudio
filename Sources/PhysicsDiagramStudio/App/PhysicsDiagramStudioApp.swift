import AppKit
import SwiftUI

@main
struct PhysicsDiagramStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var diagramStore = DiagramStore()
    @State private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup("Physics Diagram Studio") {
            ContentView(store: diagramStore, settings: settingsStore)
                .frame(minWidth: 980, minHeight: 680)
                .preferredColorScheme(.light)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
