// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MindDesk",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MindDeskCore", targets: ["MindDeskCore"]),
        .executable(name: "MindDesk", targets: ["MindDesk"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MindDeskCore",
            path: "Sources/MindDeskCore"
        ),
        .executableTarget(
            name: "MindDesk",
            dependencies: ["MindDeskCore"],
            path: "Sources/MindDesk",
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MindDeskCoreTests",
            dependencies: ["MindDeskCore"],
            path: "Tests/MindDeskCoreTests",
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "MindDeskTests",
            dependencies: ["MindDesk", "MindDeskCore"],
            path: "Tests/MindDeskTests"
        )
    ]
)
