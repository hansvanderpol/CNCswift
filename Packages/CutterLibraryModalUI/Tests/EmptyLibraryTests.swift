import CNCCutters
import CNCCuttersStore
import CNCStorage
import Foundation
import Synchronization
import Testing

@testable import CutterLibraryModalUI

/// Timed first-valid-cutter scenario (SC-006).
///
/// Starting from an absent library, the editor must guide a user to one valid stored cutter without
/// external help: every required field reports what is missing, filling exactly those fields is
/// sufficient, and the modal coordinator persists the result through the shared store.

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

@Test @MainActor func emptyLibraryReachesAStoredValidCutterWithoutHelp() async throws {
    let fileSystem = FakeFileSystem()
    let libraryURL = URL(fileURLWithPath: "/sandbox/library.json")
    let store = CutterLibraryStore(fileSystem: fileSystem)
    let coordinator = CutterLibraryCoordinator(store: store, libraryURL: libraryURL)

    let initial = try await store.load(from: libraryURL)
    guard case .absent = initial else {
        Issue.record("expected an absent library, got \(initial)")
        return
    }

    let editor = CutterEditorModel()
    let required = editor.requiredFields()
    #expect(!required.isEmpty, "the editor must tell a new user which fields to enter")
    for field in required {
        let message = try #require(editor.fieldError(field))
        #expect(!message.isEmpty, "\(field) must explain what to enter")
    }

    let start = ContinuousClock.now
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
    let first = try editor.makeCutter()
    let elapsed = start.duration(to: .now)
    #expect(elapsed < .seconds(5), "first-valid-cutter entry must be immediate (SC-006)")

    try CutterValidator.validate(first)
    try await coordinator.save(first)

    let stored = try await store.load(from: libraryURL)
    guard case .loaded(let cutters) = stored else {
        Issue.record("expected the first cutter to be stored, got \(stored)")
        return
    }
    #expect(cutters == [first])

    // The same path works a second time with no library fixture to start from.
    editor.fields[.name] = "4mm flat"
    editor.fields[.cuttingDiameter] = "4"
    editor.fields[.shankDiameter] = "4"
    let second = try editor.makeCutter()
    try await coordinator.save(second)

    let updated = try await store.load(from: libraryURL)
    guard case .loaded(let both) = updated else {
        Issue.record("expected both cutters to be stored, got \(updated)")
        return
    }
    #expect(both.count == 2)
    #expect(both.contains(first))
    #expect(both.contains(second))
}
