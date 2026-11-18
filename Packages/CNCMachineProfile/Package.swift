// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCMachineProfile",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCMachineProfile", targets: ["CNCMachineProfile"])
    ],
    targets: [
        .target(
            name: "CNCMachineProfile",
            path: "Sources",
            resources: [.process("Resources")],
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCMachineProfileTests",
            dependencies: ["CNCMachineProfile"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
