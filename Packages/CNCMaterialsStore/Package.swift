// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCMaterialsStore",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCMaterialsStore", targets: ["CNCMaterialsStore"])
    ],
    dependencies: [
        .package(path: "../CNCMaterials"),
        .package(path: "../CNCStorage"),
    ],
    targets: [
        .target(
            name: "CNCMaterialsStore",
            dependencies: [
                .product(name: "CNCMaterials", package: "CNCMaterials"),
                .product(name: "CNCStorage", package: "CNCStorage"),
            ],
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCMaterialsStoreTests",
            dependencies: [
                "CNCMaterialsStore",
                .product(name: "CNCMaterials", package: "CNCMaterials"),
                .product(name: "CNCStorage", package: "CNCStorage"),
            ],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
