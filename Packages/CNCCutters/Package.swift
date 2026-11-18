// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCCutters",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCCutters", targets: ["CNCCutters"])
    ],
    targets: [
        .target(
            name: "CNCCutters",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCCuttersTests",
            dependencies: ["CNCCutters"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
