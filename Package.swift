// swift-tools-version: 6.4

import PackageDescription

/// Local packages that make up the CNCswift workspace.
///
/// Each package owns one module and is declared here as a path dependency so a single
/// `swift build` / `swift test` from the repository root covers the whole workspace.
let moduleNames = [
    "CNCMachineProfile",
    "CNCDiagnostics",
    "CNCStorage",
    "CNCGeometry",
    "CNCSTL",
    "CNCCutters",
    "CNCCuttersStore",
    "CNCMaterials",
    "CNCMaterialsStore",
    "CNCToolpath",
    "CNCGCode",
    "CNCValidation",
    "CNCSimulation",
    "CNCPipeline",
    "MainScreenUI",
    "CutterLibraryModalUI",
]

let strictSettings: [SwiftSetting] = [
    .unsafeFlags(["-strict-concurrency=complete", "-warnings-as-errors"])
]

let package = Package(
    name: "CNCswift",
    platforms: [.macOS(.v27)],
    products: [
        .executable(name: "CNCswiftApp", targets: ["CNCswiftApp"])
    ],
    dependencies: moduleNames.map { .package(path: "Packages/\($0)") },
    targets: [
        .executableTarget(
            name: "CNCswiftApp",
            dependencies: moduleNames.map { .product(name: $0, package: $0) },
            path: "App/Sources/CNCswiftApp",
            swiftSettings: strictSettings
        )
    ],
    swiftLanguageModes: [.v6]
)
