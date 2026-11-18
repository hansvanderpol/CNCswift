import Foundation
import Testing

/// Build-graph guard for the package boundaries required by FR-015, FR-059 and C1/C2.
/// It reads manifests as text, so it cannot be fooled by an import hidden behind a typealias.
private let packageNames = [
    "CNCMachineProfile", "CNCDiagnostics", "CNCStorage", "CNCGeometry", "CNCSTL",
    "CNCCutters", "CNCCuttersStore", "CNCMaterials", "CNCMaterialsStore", "CNCToolpath",
    "CNCGCode", "CNCValidation", "CNCSimulation", "CNCPipeline", "MainScreenUI",
    "CutterLibraryModalUI",
]

private let domainPackages = Set(packageNames.filter { !$0.hasSuffix("UI") })

private func repositoryRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 {
        url = url.deletingLastPathComponent()
    }
    return url
}

private func manifest(_ name: String) throws -> String {
    let url = repositoryRoot()
        .appendingPathComponent("Packages", isDirectory: true)
        .appendingPathComponent(name, isDirectory: true)
        .appendingPathComponent("Package.swift")
    return try String(contentsOf: url, encoding: .utf8)
}

@Test func validationDoesNotDependOnEmitter() throws {
    let text = try manifest("CNCValidation")
    #expect(!text.contains("CNCGCode"))
}

@Test func plannerDoesNotDependOnEmitterValidatorOrPipeline() throws {
    let text = try manifest("CNCToolpath")
    #expect(!text.contains("CNCGCode"))
    #expect(!text.contains("CNCValidation"))
    #expect(!text.contains("CNCPipeline"))
}

@Test func noDomainPackageImportsSwiftUIOrRealityKit() throws {
    for name in domainPackages {
        let text = try manifest(name)
        #expect(!text.contains("SwiftUI"), "\(name) must not import SwiftUI")
        #expect(!text.contains("RealityKit"), "\(name) must not import RealityKit")
    }
}

@Test func noStageDependsOnPipeline() throws {
    for name in ["CNCSTL", "CNCToolpath", "CNCGCode", "CNCValidation", "CNCSimulation"] {
        let text = try manifest(name)
        #expect(!text.contains("CNCPipeline"), "\(name) must not depend on CNCPipeline")
    }
}

@Test func presentationModulesDoNotImportEachOther() throws {
    #expect(!(try manifest("MainScreenUI")).contains("CutterLibraryModalUI"))
    #expect(!(try manifest("CutterLibraryModalUI")).contains("MainScreenUI"))
}
