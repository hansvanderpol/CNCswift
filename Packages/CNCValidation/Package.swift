// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCValidation",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCValidation", targets: ["CNCValidation"])
    ],
    dependencies: [
        .package(path: "../CNCDiagnostics"),
        .package(path: "../CNCGeometry"),
        .package(path: "../CNCMachineProfile"),
    ],
    targets: [
        .target(
            name: "CNCValidation",
            dependencies: [
                .product(name: "CNCDiagnostics", package: "CNCDiagnostics"),
                .product(name: "CNCGeometry", package: "CNCGeometry"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
            ],
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCValidationTests",
            dependencies: [
                "CNCValidation",
                .product(name: "CNCDiagnostics", package: "CNCDiagnostics"),
                .product(name: "CNCGeometry", package: "CNCGeometry"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
            ],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
