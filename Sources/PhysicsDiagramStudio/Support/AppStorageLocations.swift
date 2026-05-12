import Foundation

enum AppStorageLocations {
    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(applicationSupportDirectoryName, isDirectory: true)
    }

    private static var applicationSupportDirectoryName: String {
        Bundle.main.bundleIdentifier ?? "com.jay.PhysicsDiagramStudio.debug"
    }
}
