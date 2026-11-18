// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCMaterials",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCMaterials", targets: ["CNCMaterials"])
    ],
    dependencies: [
        .package(path: "../CNCCutters"),
        .package(path: "../CNCMachineProfile"),
    ],
    targets: [
        .target(
            name: "CNCMaterials",
            dependencies: [
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
            ],
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCMaterialsTests",
            dependencies: [
                "CNCMaterials",
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
            ],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
