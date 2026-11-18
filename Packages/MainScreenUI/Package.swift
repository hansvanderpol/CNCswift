// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "MainScreenUI",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "MainScreenUI", targets: ["MainScreenUI"])
    ],
    targets: [
        .target(
            name: "MainScreenUI",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "MainScreenUITests",
            dependencies: ["MainScreenUI"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
