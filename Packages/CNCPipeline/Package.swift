// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCPipeline",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCPipeline", targets: ["CNCPipeline"])
    ],
    dependencies: [
        .package(path: "../CNCCutters"),
        .package(path: "../CNCCuttersStore"),
        .package(path: "../CNCDiagnostics"),
        .package(path: "../CNCGCode"),
        .package(path: "../CNCMachineProfile"),
        .package(path: "../CNCMaterials"),
        .package(path: "../CNCMaterialsStore"),
        .package(path: "../CNCSimulation"),
        .package(path: "../CNCSTL"),
        .package(path: "../CNCToolpath"),
        .package(path: "../CNCValidation"),
        .package(path: "../CutterLibraryModalUI"),
        .package(path: "../MainScreenUI"),
    ],
    targets: [
        .target(
            name: "CNCPipeline",
            dependencies: [
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCCuttersStore", package: "CNCCuttersStore"),
                .product(name: "CNCDiagnostics", package: "CNCDiagnostics"),
                .product(name: "CNCGCode", package: "CNCGCode"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
                .product(name: "CNCMaterials", package: "CNCMaterials"),
                .product(name: "CNCMaterialsStore", package: "CNCMaterialsStore"),
                .product(name: "CNCSimulation", package: "CNCSimulation"),
                .product(name: "CNCSTL", package: "CNCSTL"),
                .product(name: "CNCToolpath", package: "CNCToolpath"),
                .product(name: "CNCValidation", package: "CNCValidation"),
            ],
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCPipelineTests",
            dependencies: [
                "CNCPipeline",
                .product(name: "CNCCutters", package: "CNCCutters"),
                .product(name: "CNCCuttersStore", package: "CNCCuttersStore"),
                .product(name: "CNCDiagnostics", package: "CNCDiagnostics"),
                .product(name: "CNCGCode", package: "CNCGCode"),
                .product(name: "CNCMachineProfile", package: "CNCMachineProfile"),
                .product(name: "CNCMaterials", package: "CNCMaterials"),
                .product(name: "CNCMaterialsStore", package: "CNCMaterialsStore"),
                .product(name: "CNCSimulation", package: "CNCSimulation"),
                .product(name: "CNCSTL", package: "CNCSTL"),
                .product(name: "CNCToolpath", package: "CNCToolpath"),
                .product(name: "CNCValidation", package: "CNCValidation"),
                .product(name: "CutterLibraryModalUI", package: "CutterLibraryModalUI"),
                .product(name: "MainScreenUI", package: "MainScreenUI"),
            ],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
