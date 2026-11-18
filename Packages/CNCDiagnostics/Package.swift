// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CNCDiagnostics",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "CNCDiagnostics", targets: ["CNCDiagnostics"])
    ],
    targets: [
        .target(
            name: "CNCDiagnostics",
            path: "Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CNCDiagnosticsTests",
            dependencies: ["CNCDiagnostics"],
            path: "Tests",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
