import CNCCutters
import CNCCuttersStore
import CNCStorage
import Foundation
import Synchronization
import Testing

@testable import CutterLibraryModalUI

/// The modal must run without the main screen module (FR-057, FR-059).
///
/// This test target links `CutterLibraryModalUI`, `CNCCutters`, `CNCCuttersStore`, and the
/// `CNCStorage` filesystem seam used by its fake. The manifest guard makes the absence of a
/// `MainScreenUI` dependency explicit, and the runtime test drives the modal entry point and view
/// model using only those dependencies. T082 owns the entry point implementation.

private enum FakeError: Error, Equatable {
    case missing
}

private final class FakeFileSystem: FileSystem, @unchecked Sendable {
    let files = Mutex<[URL: Data]>([:])

    func read(_ url: URL) throws -> Data {
        guard let data = files.withLock({ $0[url] }) else { throw FakeError.missing }
        return data
    }

    func write(_ data: Data, to url: URL) throws {
        files.withLock { $0[url] = data }
    }

    func replace(_ data: Data, at url: URL, backupURL: URL) throws {
        files.withLock { storage in
            if let previous = storage[url] {
                storage[backupURL] = previous
            }
            storage[url] = data
        }
    }

    func exists(_ url: URL) -> Bool {
        files.withLock { $0[url] != nil }
    }

    func remove(_ url: URL) throws {
        files.withLock { $0[url] = nil }
    }
}

private func repositoryRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 {
        url = url.deletingLastPathComponent()
    }
    return url
}

private func manifest(_ name: String) throws -> String {
    try String(
        contentsOf: repositoryRoot()
            .appendingPathComponent("Packages", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent("Package.swift"),
        encoding: .utf8
    )
}

@Test func modalPackageDoesNotDependOnTheMainScreen() throws {
    let modalManifest = try manifest("CutterLibraryModalUI")
    #expect(!modalManifest.contains("MainScreenUI"))
    #expect(!(try manifest("MainScreenUI")).contains("CutterLibraryModalUI"))
}

@Test @MainActor func modalEntryPointAndEditorRunWithoutTheMainScreen() async throws {
    let fileSystem = FakeFileSystem()
    let libraryURL = URL(fileURLWithPath: "/sandbox/library.json")
    let store = CutterLibraryStore(fileSystem: fileSystem)
    let modal = LibraryModal(store: store, libraryURL: libraryURL)
    let editor = CutterEditorModel()

    let initialCutters = try await modal.loadCutters()
    #expect(initialCutters.isEmpty)

    editor.type = .flat
    editor.fields = [
        .name: "6mm flat",
        .shankDiameter: "6",
        .cuttingLength: "20",
        .fluteCount: "2",
        .feedRate: "750",
        .spindleSpeed: "8000",
        .cuttingDiameter: "6",
    ]
    let cutter = try editor.makeCutter()
    try await CutterLibraryCoordinator(store: store, libraryURL: libraryURL).save(cutter)

    let loadedCutters = try await modal.loadCutters()
    #expect(loadedCutters == [cutter])
    #expect(editor.requiredFields().contains(.cuttingDiameter))
}
