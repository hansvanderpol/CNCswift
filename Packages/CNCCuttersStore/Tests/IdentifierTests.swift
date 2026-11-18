import CNCCutters
import CNCStorage
import Foundation
import Synchronization
import Testing

@testable import CNCCuttersStore

private struct LibraryDocument: Codable, Equatable, Sendable {
    var cutters: [Cutter]
}

private struct DocumentEnvelope<Payload: Codable>: Codable {
    var payload: Payload
    var schemaVersion: Int
}

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

private func cutter() -> Cutter {
    Cutter(
        id: CutterID("stable-cutter-id"),
        name: "Original name",
        type: .flat,
        shankDiameter: 6,
        cuttingLength: 20,
        fluteCount: 2,
        feedRate: 750,
        spindleSpeed: 8000,
        cuttingDiameter: 6,
        ballDiameter: nil,
        includedAngle: nil,
        tipDiameter: nil
    )
}

@Test func identifierSurvivesEditSaveReloadAndMigration() async throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let original = cutter()
    let legacy = DocumentEnvelope(payload: LibraryDocument(cutters: [original]), schemaVersion: 0)
    try fs.write(try JSONEncoder().encode(legacy), to: url)

    let migrations: [Int: @Sendable (Data) throws -> Data] = [
        0: { data in
            var document = try JSONDecoder().decode(
                DocumentEnvelope<LibraryDocument>.self, from: data)
            document.schemaVersion = 1
            return try JSONEncoder().encode(document)
        }
    ]
    let sut = CutterLibraryStore(fileSystem: fs, currentVersion: 1, migrations: migrations)

    let migrated = try await sut.load(from: url)
    guard case .migrated(from: _, cutters: let migratedCutters) = migrated else {
        Issue.record("expected migrated")
        return
    }
    let loaded = try #require(migratedCutters.first)
    #expect(loaded.id == original.id)

    let edited = loaded.renamed(to: "New name")
    #expect(edited.id == original.id)
    try await sut.save([edited], to: url)

    let reloaded = try await sut.load(from: url)
    guard case .loaded(let reloadedCutters) = reloaded else {
        Issue.record("expected loaded")
        return
    }
    #expect(reloadedCutters.first?.id == original.id)
    #expect(reloadedCutters.first?.name == "New name")
}
