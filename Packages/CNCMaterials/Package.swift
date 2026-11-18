// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCMaterials",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCMaterials", targets: ["CNCMaterials"])
    ],
    targets: [
        .target(
            name: "CNCMaterials",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCMaterialsTests",
            dependencies: ["CNCMaterials"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
