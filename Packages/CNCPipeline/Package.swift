// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCPipeline",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCPipeline", targets: ["CNCPipeline"])
    ],
    targets: [
        .target(
            name: "CNCPipeline",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCPipelineTests",
            dependencies: ["CNCPipeline"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
