// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCGCode",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCGCode", targets: ["CNCGCode"])
    ],
    dependencies: [
        .package(path: "../CNCCutters"),
        .package(path: "../CNCDiagnostics"),
        .package(path: "../CNCGeometry"),
        .package(path: "../CNCMachineProfile"),
        .package(path: "../CNCMaterials"),
        .package(path: "../CNCStorage"),
        .package(path: "../CNCToolpath"),
    ],
    targets: [
        .target(
            name: "CNCGCode",
            dependencies: [
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCDiagnostics", package: "CNCDiagnostics"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
                .product(name: "CNCMaterials", package: "CNCMaterials"),
                .product(name: "CNCStorage", package: "CNCStorage"),
                .product(name: "CNCToolpath", package: "CNCToolpath"),
            ],
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCGCodeTests",
            dependencies: [
                "CNCGCode",
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCDiagnostics", package: "CNCDiagnostics"),
                .product(name: "CNCGeometry", package: "CNCGeometry"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
                .product(name: "CNCMaterials", package: "CNCMaterials"),
                .product(name: "CNCStorage", package: "CNCStorage"),
                .product(name: "CNCToolpath", package: "CNCToolpath"),
            ],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
