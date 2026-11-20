// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCSimulation",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCSimulation", targets: ["CNCSimulation"])
    ],
    dependencies: [
        .package(path: "../CNCCutters"),
        .package(path: "../CNCDiagnostics"),
        .package(path: "../CNCGeometry"),
        .package(path: "../CNCMachineProfile"),
        .package(path: "../CNCMaterials"),
        .package(path: "../CNCToolpath"),
        .package(path: "../CNCValidation"),
    ],
    targets: [
        .target(
            name: "CNCSimulation",
            dependencies: [
                .product(name: "CNCDiagnostics", package: "CNCDiagnostics"),
                .product(name: "CNCGeometry", package: "CNCGeometry"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
                .product(name: "CNCToolpath", package: "CNCToolpath"),
                .product(name: "CNCValidation", package: "CNCValidation"),
            ],
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCSimulationTests",
            dependencies: [
                "CNCSimulation",
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCDiagnostics", package: "CNCDiagnostics"),
                .product(name: "CNCGeometry", package: "CNCGeometry"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
                .product(name: "CNCMaterials", package: "CNCMaterials"),
                .product(name: "CNCToolpath", package: "CNCToolpath"),
                .product(name: "CNCValidation", package: "CNCValidation"),
            ],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
