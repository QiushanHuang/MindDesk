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
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0")
    ],
    targets: [
        .target(
            name: "MindDeskCore",
            path: "Sources/MindDeskCore"
        ),
        .executableTarget(
            name: "MindDesk",
            dependencies: [
                "MindDeskCore",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/MindDesk",
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MindDeskCoreTests",
            dependencies: ["MindDeskCore"],
            path: "Tests/MindDeskCoreTests"
        ),
        .testTarget(
            name: "MindDeskTests",
            dependencies: ["MindDesk", "MindDeskCore"],
            path: "Tests/MindDeskTests"
        )
    ]
)
