import CNCCutters
import CNCGCode
import CNCGeometry
import CNCMachineProfile
import CNCMaterials
import CNCStorage
import CNCToolpath
import Foundation
import Synchronization
import Testing

private final class FakeFileSystem: FileSystem, @unchecked Sendable {
    let files = Mutex<[URL: Data]>([:])
    let failOnWrite = Mutex<Bool>(false)
    let failOnReplace = Mutex<Bool>(false)
    let writes = Mutex<[URL]>([])

    func read(_ url: URL) throws -> Data {
        guard let data = files.withLock({ $0[url] }) else { throw CocoaError(.fileReadNoSuchFile) }
        return data
    }

    func write(_ data: Data, to url: URL) throws {
        try Task.checkCancellation()
        if failOnWrite.withLock({ $0 }) { throw CocoaError(.fileWriteNoPermission) }
        writes.withLock { $0.append(url) }
        files.withLock { $0[url] = data }
    }

    func replace(_ data: Data, at url: URL, backupURL: URL) throws {
        try Task.checkCancellation()
        if failOnReplace.withLock({ $0 }) { throw CocoaError(.fileWriteNoPermission) }
        writes.withLock { $0.append(url) }
        let previous = files.withLock { $0[url] }
        files.withLock { storage in
            if let previous { storage[backupURL] = previous }
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

private func sampleProgram(modelFileName: String = "relief-demo-binary.stl") throws
    -> RenderedProgram
{
    let record = GenerationRecord(
        cutter: EmitterFixture.cutter,
        material: EmitterFixture.material,
        job: try EmitterFixture.job(),
        profile: TTC450Pro.profile,
        appliedScale: 1.0,
        modelFileName: modelFileName,
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    return RenderedProgram(text: "G21\nM30\n", record: record)
}

@Test func writesProgramAtomicallyWithNcExtension() async throws {
    let fs = FakeFileSystem()
    let writer = FileWriter(fileSystem: fs)
    let url = URL(fileURLWithPath: "/tmp/output/model.gcode")

    try await writer.write(try sampleProgram(), to: url)

    let stored = fs.files.withLock { $0 }
    #expect(stored.count == 1)
    let writtenURL = try #require(stored.keys.first)
    #expect(writtenURL.pathExtension == "nc")
    #expect(String(data: try #require(stored.values.first), encoding: .utf8) == "G21\nM30\n")
}

@Test func derivesDeterministicASCIIFileNameFromModelBasename() async throws {
    let fs = FakeFileSystem()
    let writer = FileWriter(fileSystem: fs)
    let destination = URL(fileURLWithPath: "/tmp/output/ignored.txt")

    try await writer.write(try sampleProgram(modelFileName: "My Model (v2).stl"), to: destination)

    let writtenURL = try #require(fs.files.withLock { $0.keys.first })
    #expect(writtenURL.lastPathComponent == "My_Model_v2_.nc")
}

@Test func emptyDerivedNameFallsBackToCarveNc() async throws {
    let fs = FakeFileSystem()
    let writer = FileWriter(fileSystem: fs)

    try await writer.write(
        try sampleProgram(modelFileName: "###.stl"), to: URL(fileURLWithPath: "/tmp/out/x"))

    let writtenURL = try #require(fs.files.withLock { $0.keys.first })
    #expect(writtenURL.lastPathComponent == "carve.nc")
}

@Test func replacesExistingFileAtomically() async throws {
    let fs = FakeFileSystem()
    let writer = FileWriter(fileSystem: fs)
    let url = URL(fileURLWithPath: "/tmp/output/relief-demo-binary.nc")
    fs.files.withLock { $0[url] = Data("old".utf8) }

    try await writer.write(
        try sampleProgram(), to: URL(fileURLWithPath: "/tmp/output/relief-demo-binary.stl"))

    #expect(fs.exists(url))
    #expect(String(data: try fs.read(url), encoding: .utf8) == "G21\nM30\n")
    // no temporary/partial file should remain
    let names = fs.files.withLock { $0.keys.map(\.lastPathComponent) }
    #expect(names.allSatisfy { !$0.contains(".tmp") })
}

@Test func noPartialFileRemainsOnFailure() async throws {
    let fs = FakeFileSystem()
    fs.failOnWrite.withLock { $0 = true }
    fs.failOnReplace.withLock { $0 = true }
    let writer = FileWriter(fileSystem: fs)
    let url = URL(fileURLWithPath: "/tmp/output/relief-demo-binary.stl")

    await #expect(throws: (any Error).self) {
        try await writer.write(try sampleProgram(), to: url)
    }

    #expect(fs.files.withLock { $0.isEmpty })
}

@Test func noFileIsWrittenOnCancellation() async throws {
    let fs = FakeFileSystem()
    let writer = FileWriter(fileSystem: fs)
    let url = URL(fileURLWithPath: "/tmp/output/relief-demo-binary.stl")

    let task = Task {
        try await writer.write(try sampleProgram(), to: url)
    }
    task.cancel()

    do {
        try await task.value
        Issue.record("expected CancellationError")
    } catch is CancellationError {
        #expect(fs.files.withLock { $0.isEmpty })
        let names = fs.files.withLock { $0.keys.map(\.lastPathComponent) }
        #expect(names.allSatisfy { !$0.contains(".tmp") })
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}
