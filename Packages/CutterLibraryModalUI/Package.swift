// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CutterLibraryModalUI",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CutterLibraryModalUI", targets: ["CutterLibraryModalUI"])
    ],
    targets: [
        .target(
            name: "CutterLibraryModalUI",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CutterLibraryModalUITests",
            dependencies: ["CutterLibraryModalUI"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
