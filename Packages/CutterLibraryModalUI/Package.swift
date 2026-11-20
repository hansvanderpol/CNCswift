// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CutterLibraryModalUI",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CutterLibraryModalUI", targets: ["CutterLibraryModalUI"])
    ],
    dependencies: [
        .package(path: "../CNCCutters"),
        .package(path: "../CNCCuttersStore"),
    ],
    targets: [
        .target(
            name: "CutterLibraryModalUI",
            dependencies: [
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCCuttersStore", package: "CNCCuttersStore"),
            ],
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CutterLibraryModalUITests",
            dependencies: [
                "CutterLibraryModalUI",
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCCuttersStore", package: "CNCCuttersStore"),
            ],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
