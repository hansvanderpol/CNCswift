// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCGCode",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCGCode", targets: ["CNCGCode"])
    ],
    targets: [
        .target(
            name: "CNCGCode",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCGCodeTests",
            dependencies: ["CNCGCode"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
