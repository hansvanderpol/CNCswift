import CNCCutters
import CNCStorage
import Foundation
import Synchronization
import Testing

@testable import CNCCuttersStore

/// Tests for the forward-only cutter migration chain (FR-052, SC-008).
///
/// These tests define the contract T081 and T088 must satisfy: `CutterMigrations` publishes the
/// current schema version and one data-to-data step per older version, and the v1/v2 fixtures live
/// in `Fixtures/library/`. No migration may drop a cutter or silently alter one of its values.

private struct DocumentEnvelope<Payload: Codable>: Codable {
    var payload: Payload
    var schemaVersion: Int
}

private struct CutterPayload: Codable, Equatable, Sendable {
    var cutters: [Cutter]
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

private func repositoryRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 {
        url = url.deletingLastPathComponent()
    }
    return url
}

private func fixtureData(_ name: String) throws -> Data {
    try Data(
        contentsOf: repositoryRoot()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("library", isDirectory: true)
            .appendingPathComponent(name)
    )
}

private func cutters(in data: Data) throws -> [Cutter] {
    try JSONDecoder()
        .decode(DocumentEnvelope<CutterPayload>.self, from: data)
        .payload
        .cutters
}

private func migratedStore(fileSystem: FakeFileSystem) -> CutterLibraryStore {
    CutterLibraryStore(
        fileSystem: fileSystem,
        currentVersion: CutterMigrations.currentVersion,
        migrations: CutterMigrations.steps
    )
}

@Test func migrationChainIsForwardOnlyAcrossTwoVersions() {
    #expect(CutterMigrations.currentVersion == 2)
    #expect(Set(CutterMigrations.steps.keys) == [1])
    for sourceVersion in CutterMigrations.steps.keys {
        #expect(sourceVersion < CutterMigrations.currentVersion)
    }
}

@Test func v2FixtureLoadsAtTheCurrentSchema() async throws {
    let fileSystem = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let data = try fixtureData("v2.json")
    let expected = try cutters(in: data)
    try fileSystem.write(data, to: url)

    let outcome = try await migratedStore(fileSystem: fileSystem).load(from: url)

    guard case .loaded(let cutters) = outcome else {
        Issue.record("expected the v2 fixture to load at the current schema, got \(outcome)")
        return
    }
    #expect(cutters == expected)
}

@Test func v1FixtureMigratesToV2WithoutLosingACutter() async throws {
    let fileSystem = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let v1Data = try fixtureData("v1.json")
    try fileSystem.write(v1Data, to: url)

    let outcome = try await migratedStore(fileSystem: fileSystem).load(from: url)

    guard case .migrated(from: let version, cutters: let migratedCutters) = outcome else {
        Issue.record("expected a v1 to v2 migration, got \(outcome)")
        return
    }
    let v2Data = try fixtureData("v2.json")
    let expected = try cutters(in: v2Data)
    #expect(version == 1)
    #expect(migratedCutters == expected)
    for cutter in migratedCutters {
        try CutterValidator.validate(cutter)
    }
}

@Test func migrationPreservesEveryIdentifierAndValue() async throws {
    let v1Data = try fixtureData("v1.json")
    let v2Data = try fixtureData("v2.json")
    let v1 = try cutters(in: v1Data)
    let v2 = try cutters(in: v2Data)

    #expect(v1.count == v2.count)
    #expect(v1.map(\.id) == v2.map(\.id))
    #expect(v1 == v2, "a schema bump must not change a cutter field (SC-008)")
}

@Test func unmigratableRecordAbortsWithoutLoss() async throws {
    #expect(
        CutterMigrations.steps[1] != nil,
        "a v1 to v2 migration step must be registered"
    )
    let fileSystem = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let backup = VersionedStore<CutterLibraryDocument>.backupURL(for: url)
    let invalid = Cutter(
        id: CutterID("unmigratable"),
        name: "invalid flat",
        type: .flat,
        shankDiameter: 6,
        cuttingLength: 20,
        fluteCount: 2,
        feedRate: 750,
        spindleSpeed: 8000,
        cuttingDiameter: -1,
        ballDiameter: nil,
        includedAngle: nil,
        tipDiameter: nil
    )
    let original = try JSONEncoder().encode(
        DocumentEnvelope(
            payload: CutterPayload(cutters: [invalid]),
            schemaVersion: 1
        )
    )
    try fileSystem.write(original, to: url)

    await #expect(throws: StorageError.self) {
        _ = try await migratedStore(fileSystem: fileSystem).load(from: url)
    }
    let storedData = try fileSystem.read(url)
    #expect(
        storedData == original,
        "the original bytes must survive a failed migration"
    )
    #expect(
        !fileSystem.exists(backup),
        "an aborted migration must not write a backup or partial file"
    )
}
