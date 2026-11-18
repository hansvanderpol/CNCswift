// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCValidation",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCValidation", targets: ["CNCValidation"])
    ],
    targets: [
        .target(
            name: "CNCValidation",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCValidationTests",
            dependencies: ["CNCValidation"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
