// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCSTL",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCSTL", targets: ["CNCSTL"])
    ],
    dependencies: [
        .package(path: "../CNCDiagnostics"),
        .package(path: "../CNCGeometry"),
    ],
    targets: [
        .target(
            name: "CNCSTL",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCSTLTests",
            dependencies: [
                "CNCSTL",
                .product(name: "CNCDiagnostics", package: "CNCDiagnostics"),
                .product(name: "CNCGeometry", package: "CNCGeometry"),
            ],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
