// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCCuttersStore",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCCuttersStore", targets: ["CNCCuttersStore"])
    ],
    dependencies: [
        .package(path: "../CNCCutters"),
        .package(path: "../CNCStorage"),
    ],
    targets: [
        .target(
            name: "CNCCuttersStore",
            dependencies: [
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCStorage", package: "CNCStorage"),
            ],
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCCuttersStoreTests",
            dependencies: [
                "CNCCuttersStore",
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCStorage", package: "CNCStorage"),
            ],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
