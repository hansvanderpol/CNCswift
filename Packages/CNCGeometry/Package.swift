// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCGeometry",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCGeometry", targets: ["CNCGeometry"])
    ],
    targets: [
        .target(
            name: "CNCGeometry",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCGeometryTests",
            dependencies: ["CNCGeometry"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
