import CNCDiagnostics
import CNCGeometry
import Foundation
import Synchronization
import Testing

@testable import CNCSTL

private struct STLTriangle {
    let normal: Vec3
    let a: Vec3
    let b: Vec3
    let c: Vec3
}

private enum STLBinaryWriter {
    static func data(_ triangles: [STLTriangle]) -> Data {
        var data = Data(repeating: 0, count: 80)
        var count = UInt32(triangles.count).littleEndian
        data.append(contentsOf: withUnsafeBytes(of: &count) { $0 })
        for triangle in triangles {
            for vertex in [triangle.normal, triangle.a, triangle.b, triangle.c] {
                for component in [vertex.x, vertex.y, vertex.z] {
                    var value = Float(component).littleEndian
                    data.append(contentsOf: withUnsafeBytes(of: &value) { $0 })
                }
            }
            data.append(contentsOf: [0, 0])
        }
        return data
    }
}

private func repositoryRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 {
        url = url.deletingLastPathComponent()
    }
    return url
}

private func fixtureURL(_ name: String) -> URL {
    repositoryRoot()
        .appendingPathComponent("Fixtures", isDirectory: true)
        .appendingPathComponent("stl", isDirectory: true)
        .appendingPathComponent(name)
}

private func temporaryURL(_ name: String, data: Data) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CNCSTLTests-\(UUID().uuidString)-\(name)")
    try data.write(to: url)
    return url
}

private func decode(
    url: URL,
    reports: Mutex<[StageProgress]>? = nil
) async throws -> MeshDocument {
    let sink = ProgressSink(
        report: { progress in reports?.withLock { $0.append(progress) } },
        isCancelled: { false }
    )
    return try await STLDecoder.decode(url: url, progress: sink)
}

@Test func asciiAndBinaryFixturesDecodeToTheSameRelief() async throws {
    let ascii = try await decode(url: fixtureURL("relief-demo-ascii.stl"))
    let binary = try await decode(url: fixtureURL("relief-demo-binary.stl"))

    #expect(ascii.encoding == .ascii)
    #expect(binary.encoding == .binary)
    #expect(ascii.triangleCount == 672)
    #expect(ascii.triangleCount == binary.triangleCount)
    #expect(ascii.bounds == binary.bounds)
    #expect(ascii.isManifold)
    #expect(ascii.degenerateTriangleCount == 0)
}

@Test func denseFixtureDecodesAll200000Triangles() async throws {
    let document = try await decode(url: fixtureURL("relief-demo-200k.stl"))
    #expect(document.triangleCount == 200_000)
    #expect(document.isManifold)
}

@Test func emptyTruncatedAndCorruptInputsAreRejected() async throws {
    let emptyURL = try temporaryURL("empty.stl", data: Data())
    defer { try? FileManager.default.removeItem(at: emptyURL) }
    await #expect(throws: DecodeError.empty) {
        try await decode(url: emptyURL)
    }

    let valid = try Data(contentsOf: fixtureURL("relief-demo-binary.stl"))
    let truncatedURL = try temporaryURL("truncated.stl", data: valid.prefix(200))
    defer { try? FileManager.default.removeItem(at: truncatedURL) }
    await #expect(throws: DecodeError.truncated) {
        try await decode(url: truncatedURL)
    }

    let corruptURL = try temporaryURL("corrupt.stl", data: Data("not an STL at all".utf8))
    defer { try? FileManager.default.removeItem(at: corruptURL) }
    await #expect(throws: DecodeError.self) {
        try await decode(url: corruptURL)
    }
}

@Test func nonManifoldAndDegenerateTrianglesAreRejected() async throws {
    let zero = Vec3(x: 0, y: 0, z: 0)
    let openTriangle = STLTriangle(
        normal: Vec3(x: 0, y: 0, z: 1),
        a: zero,
        b: Vec3(x: 1, y: 0, z: 0),
        c: Vec3(x: 1, y: 1, z: 0)
    )
    let openURL = try temporaryURL("non-manifold.stl", data: STLBinaryWriter.data([openTriangle]))
    defer { try? FileManager.default.removeItem(at: openURL) }
    await #expect(throws: DecodeError.nonManifold) {
        try await decode(url: openURL)
    }

    let degenerate = STLTriangle(normal: zero, a: zero, b: zero, c: zero)
    let degenerateURL = try temporaryURL(
        "degenerate.stl",
        data: STLBinaryWriter.data([degenerate])
    )
    defer { try? FileManager.default.removeItem(at: degenerateURL) }
    await #expect(throws: DecodeError.degenerate) {
        try await decode(url: degenerateURL)
    }
}

@Test func rejectionNamesTheFileAndDefect() async throws {
    let valid = try Data(contentsOf: fixtureURL("relief-demo-binary.stl"))
    let url = try temporaryURL("broken-relief.stl", data: valid.prefix(200))
    defer { try? FileManager.default.removeItem(at: url) }

    do {
        _ = try await decode(url: url)
        Issue.record("expected a truncated STL failure")
    } catch let failure as any CNCError {
        #expect(failure.userMessage.contains("broken-relief.stl"))
        #expect(failure.userMessage.localizedCaseInsensitiveContains("truncated"))
    } catch {
        Issue.record("expected CNCError, got \(error)")
    }
}

@Test func progressIsReportedFrom50000Triangles() async throws {
    let reports = Mutex<[StageProgress]>([])

    _ = try await decode(url: fixtureURL("relief-demo-200k.stl"), reports: reports)

    #expect(reports.withLock { $0.contains { $0.completed >= 50_000 } })
}
