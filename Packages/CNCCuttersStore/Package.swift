// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCCuttersStore",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCCuttersStore", targets: ["CNCCuttersStore"])
    ],
    targets: [
        .target(
            name: "CNCCuttersStore",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCCuttersStoreTests",
            dependencies: ["CNCCuttersStore"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
