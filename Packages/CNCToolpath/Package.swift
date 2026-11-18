// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCToolpath",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCToolpath", targets: ["CNCToolpath"])
    ],
    targets: [
        .target(
            name: "CNCToolpath",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCToolpathTests",
            dependencies: ["CNCToolpath"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
