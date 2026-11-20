// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "MainScreenUI",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "MainScreenUI", targets: ["MainScreenUI"])
    ],
    dependencies: [
        .package(path: "../CNCCutters"),
        .package(path: "../CNCMachineProfile"),
        .package(path: "../CNCMaterials"),
        .package(path: "../CNCToolpath"),
    ],
    targets: [
        .target(
            name: "MainScreenUI",
            dependencies: [
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
                .product(name: "CNCMaterials", package: "CNCMaterials"),
                .product(name: "CNCToolpath", package: "CNCToolpath"),
            ],
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "MainScreenUITests",
            dependencies: [
                "MainScreenUI",
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
                .product(name: "CNCMaterials", package: "CNCMaterials"),
                .product(name: "CNCToolpath", package: "CNCToolpath"),
            ],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
