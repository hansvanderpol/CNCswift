import Foundation
import Testing

/// G-code write-boundary guard for FR-027 and C2/C3 (plan task-shaping note 1).
///
/// `CNCGCode` owns the atomic `FileWriter`; `CNCPipeline` is the only orchestrator allowed to call
/// `commit` and reach it. No other package may reference the writer API or depend on the writer's
/// package. Library/store persistence writes live in `CNCStorage` through the injected
/// `FileSystem` seam and are a separate concern; this guard is specifically about the G-code
/// program-writing path that produces the `.nc` output file.
private let packageNames = [
    "CNCMachineProfile", "CNCDiagnostics", "CNCStorage", "CNCGeometry", "CNCSTL",
    "CNCCutters", "CNCCuttersStore", "CNCMaterials", "CNCMaterialsStore", "CNCToolpath",
    "CNCGCode", "CNCValidation", "CNCSimulation", "CNCPipeline", "MainScreenUI",
    "CutterLibraryModalUI",
]

/// The only packages permitted to reference the program-writer API.
private let writerOwners: Set<String> = ["CNCGCode", "CNCPipeline"]

/// Signatures that identify the G-code program-writing path.
private let writerSignatures = ["ProgramWriter", "FileWriter"]

private func repositoryRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 {
        url = url.deletingLastPathComponent()
    }
    return url
}

private func swiftFiles(in package: String, root: URL) throws -> [URL] {
    let sources =
        root
        .appendingPathComponent("Packages", isDirectory: true)
        .appendingPathComponent(package, isDirectory: true)
        .appendingPathComponent("Sources", isDirectory: true)
    guard FileManager.default.fileExists(atPath: sources.path) else { return [] }
    return try FileManager.default.subpathsOfDirectory(atPath: sources.path)
        .filter { $0.hasSuffix(".swift") }
        .map { sources.appendingPathComponent($0) }
}

@Test func onlyWriterPackagesReferenceTheProgramWriter() throws {
    let root = repositoryRoot()
    var violators: Set<String> = []
    for package in packageNames {
        for file in try swiftFiles(in: package, root: root) {
            let text = try String(contentsOf: file, encoding: .utf8)
            if writerSignatures.contains(where: { text.contains($0) }) {
                violators.insert(package)
            }
        }
    }
    let unexpected = violators.subtracting(writerOwners)
    #expect(
        unexpected.isEmpty,
        "Program-writer API referenced outside \(writerOwners.sorted()): \(unexpected.sorted())"
    )
}

@Test func onlyThePipelinePackageDependsOnTheWriter() throws {
    let root = repositoryRoot()
    var dependents: Set<String> = []
    for package in packageNames {
        let manifest =
            root
            .appendingPathComponent("Packages", isDirectory: true)
            .appendingPathComponent(package, isDirectory: true)
            .appendingPathComponent("Package.swift")
        let text = try String(contentsOf: manifest, encoding: .utf8)
        if text.contains(".package(path: \"../CNCGCode\")") {
            dependents.insert(package)
        }
    }
    let allowed: Set<String> = ["CNCPipeline"]
    let unexpected = dependents.subtracting(allowed)
    #expect(
        unexpected.isEmpty,
        "Package may not reach the G-code writer: \(unexpected.sorted())"
    )
    #expect(dependents.contains("CNCPipeline"), "the pipeline must depend on the writer package")
}
