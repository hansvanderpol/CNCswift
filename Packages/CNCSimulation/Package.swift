// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCSimulation",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCSimulation", targets: ["CNCSimulation"])
    ],
    targets: [
        .target(
            name: "CNCSimulation",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCSimulationTests",
            dependencies: ["CNCSimulation"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
