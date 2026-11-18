// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCStorage",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCStorage", targets: ["CNCStorage"])
    ],
    targets: [
        .target(
            name: "CNCStorage",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCStorageTests",
            dependencies: ["CNCStorage"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
