// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PhysicsDiagramStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PhysicsDiagramStudio", targets: ["PhysicsDiagramStudio"])
    ],
    targets: [
        .executableTarget(
            name: "PhysicsDiagramStudio",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        )
    ]
)
