// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCToolpath",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCToolpath", targets: ["CNCToolpath"])
    ],
    dependencies: [
        .package(path: "../CNCCutters"),
        .package(path: "../CNCDiagnostics"),
        .package(path: "../CNCGeometry"),
        .package(path: "../CNCMachineProfile"),
        .package(path: "../CNCMaterials"),
    ],
    targets: [
        .target(
            name: "CNCToolpath",
            dependencies: [
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCDiagnostics", package: "CNCDiagnostics"),
                .product(name: "CNCGeometry", package: "CNCGeometry"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
                .product(name: "CNCMaterials", package: "CNCMaterials"),
            ],
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCToolpathTests",
            dependencies: [
                "CNCToolpath",
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCDiagnostics", package: "CNCDiagnostics"),
                .product(name: "CNCGeometry", package: "CNCGeometry"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
                .product(name: "CNCMaterials", package: "CNCMaterials"),
            ],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
