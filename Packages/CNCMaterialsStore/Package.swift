// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCMaterialsStore",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCMaterialsStore", targets: ["CNCMaterialsStore"])
    ],
    targets: [
        .target(
            name: "CNCMaterialsStore",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCMaterialsStoreTests",
            dependencies: ["CNCMaterialsStore"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
