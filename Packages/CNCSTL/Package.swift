// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCSTL",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCSTL", targets: ["CNCSTL"])
    ],
    targets: [
        .target(
            name: "CNCSTL",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCSTLTests",
            dependencies: ["CNCSTL"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
