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
    case write
}

private final class FakeFileSystem: FileSystem, @unchecked Sendable {
    let files = Mutex<[URL: Data]>([:])
    let failReplace = Mutex(false)

    func read(_ url: URL) throws -> Data {
        guard let data = files.withLock({ $0[url] }) else { throw FakeError.missing }
        return data
    }

    func write(_ data: Data, to url: URL) throws {
        files.withLock { $0[url] = data }
    }

    func replace(_ data: Data, at url: URL, backupURL: URL) throws {
        guard !failReplace.withLock({ $0 }) else { throw FakeError.write }
        let previous = files.withLock { $0[url] }
        files.withLock { storage in
            if let previous {
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

private func cutter(id: String = "cutter-1", name: String = "6mm flat") -> Cutter {
    Cutter(
        id: CutterID(id),
        name: name,
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

private func store(
    fileSystem: FakeFileSystem,
    currentVersion: Int = 1,
    migrations: [Int: @Sendable (Data) throws -> Data] = [:]
) -> CutterLibraryStore {
    CutterLibraryStore(
        fileSystem: fileSystem,
        currentVersion: currentVersion,
        migrations: migrations
    )
}

@Test func saveAndLoadRoundTripPreservesTheCutter() async throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let original = cutter()
    let sut = store(fileSystem: fs)

    try await sut.save([original], to: url)
    let outcome = try await sut.load(from: url)

    guard case .loaded(let cutters) = outcome else {
        Issue.record("expected loaded")
        return
    }
    #expect(cutters == [original])
}

@Test func missingDocumentLoadsAsAbsent() async throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/absent-library.json")

    let outcome = try await store(fileSystem: fs).load(from: url)

    guard case .absent = outcome else {
        Issue.record("expected absent")
        return
    }
}

@Test func secondSaveRetainsThePreviousFileAsBackup() async throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let backup = URL(fileURLWithPath: "/sandbox/library.json.backup")
    let original = cutter()
    let edited = original.renamed(to: "6mm flat, sharpened")
    let sut = store(fileSystem: fs)

    try await sut.save([original], to: url)
    try await sut.save([edited], to: url)

    let backupDocument = try JSONDecoder().decode(
        DocumentEnvelope<LibraryDocument>.self,
        from: fs.read(backup)
    )
    let currentDocument = try JSONDecoder().decode(
        DocumentEnvelope<LibraryDocument>.self,
        from: fs.read(url)
    )
    #expect(backupDocument.schemaVersion == 1)
    #expect(backupDocument.payload.cutters == [original])
    #expect(currentDocument.payload.cutters == [edited])
}

@Test func olderDocumentMigratesForwardWithoutLosingTheCutter() async throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let original = cutter()
    let oldDocument = DocumentEnvelope(
        payload: LibraryDocument(cutters: [original]), schemaVersion: 0)
    try fs.write(try JSONEncoder().encode(oldDocument), to: url)

    let migrations: [Int: @Sendable (Data) throws -> Data] = [
        0: { data in
            var document = try JSONDecoder().decode(
                DocumentEnvelope<LibraryDocument>.self, from: data)
            document.schemaVersion = 1
            return try JSONEncoder().encode(document)
        }
    ]
    let outcome = try await store(fileSystem: fs, migrations: migrations).load(from: url)

    guard case .migrated(from: let version, cutters: let cutters) = outcome else {
        Issue.record("expected migrated")
        return
    }
    #expect(version == 0)
    #expect(cutters == [original])
}
