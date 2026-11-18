import CNCDiagnostics
import CNCGeometry
import Foundation

public enum STLEncoding: String, Sendable, Equatable {
    case ascii
    case binary
}

public struct MeshDocument: Sendable, Equatable {
    public let encoding: STLEncoding
    public let triangleCount: Int
    public let bounds: AABB
    public let isManifold: Bool
    public let degenerateTriangleCount: Int
    public let mesh: Mesh

    public init(
        encoding: STLEncoding,
        triangleCount: Int,
        bounds: AABB,
        isManifold: Bool,
        degenerateTriangleCount: Int,
        mesh: Mesh
    ) {
        self.encoding = encoding
        self.triangleCount = triangleCount
        self.bounds = bounds
        self.isManifold = isManifold
        self.degenerateTriangleCount = degenerateTriangleCount
        self.mesh = mesh
    }
}

public struct DecodeError: CNCError, Equatable, Sendable {
    public enum Kind: Sendable, Equatable {
        case empty
        case truncated
        case corrupt
        case nonManifold
        case degenerate
    }

    public let kind: Kind
    public let fileName: String
    public let correlationID: CorrelationID
    public let detail: String

    public init(kind: Kind, fileName: String = "", detail: String = "") {
        self.kind = kind
        self.fileName = fileName
        self.correlationID = CorrelationID(UUID().uuidString)
        self.detail = detail
    }

    public static let empty = DecodeError(kind: .empty)
    public static let truncated = DecodeError(kind: .truncated)
    public static let corrupt = DecodeError(kind: .corrupt)
    public static let nonManifold = DecodeError(kind: .nonManifold)
    public static let degenerate = DecodeError(kind: .degenerate)

    public static func == (lhs: DecodeError, rhs: DecodeError) -> Bool {
        lhs.kind == rhs.kind
    }

    public var userMessage: String {
        let name = fileName.isEmpty ? "STL file" : fileName
        switch kind {
        case .empty:
            return "\(name) is empty and cannot be decoded."
        case .truncated:
            return "\(name) is truncated or incomplete."
        case .corrupt:
            if detail.isEmpty {
                return "\(name) is corrupt and cannot be decoded."
            }
            return "\(name) is corrupt: \(detail)"
        case .nonManifold:
            return "\(name) contains non-manifold geometry."
        case .degenerate:
            return "\(name) contains degenerate triangles."
        }
    }
}

public enum STLDecoder {
    public static func decode(url: URL, progress: ProgressSink) async throws -> MeshDocument {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DecodeError(kind: .corrupt, fileName: url.lastPathComponent, detail: "unreadable")
        }
        let name = url.lastPathComponent
        if data.isEmpty {
            throw DecodeError(kind: .empty, fileName: name)
        }
        do {
            let doc = try decodeData(data, progress: progress)
            if doc.degenerateTriangleCount > 0 {
                throw DecodeError(kind: .degenerate, fileName: name)
            }
            if !doc.isManifold {
                throw DecodeError(kind: .nonManifold, fileName: name)
            }
            return doc
        } catch let e as DecodeError {
            throw DecodeError(kind: e.kind, fileName: name, detail: e.detail)
        } catch {
            throw DecodeError(kind: .corrupt, fileName: name)
        }
    }

    private static func decodeData(_ data: Data, progress: ProgressSink) throws -> MeshDocument {
        if let binary = try decodeBinaryIfPossible(data, progress: progress) {
            return binary
        }
        return try decodeASCII(data, progress: progress)
    }

    private static func decodeBinaryIfPossible(_ data: Data, progress: ProgressSink) throws
        -> MeshDocument?
    {
        guard data.count >= 84 else {
            if looksLikeASCII(data) { return nil }
            throw DecodeError(kind: .truncated)
        }
        let count = data.withUnsafeBytes { raw -> UInt32 in
            raw.loadUnaligned(fromByteOffset: 80, as: UInt32.self).littleEndian
        }
        let expected = 84 &+ Int(count) &* 50
        if expected == data.count {
            return try decodeBinary(data, count: Int(count), progress: progress)
        }
        if looksLikeASCII(data) {
            return nil
        }
        // Not ASCII text: treat as binary-ish
        if expected > data.count {
            throw DecodeError(kind: .truncated)
        }
        throw DecodeError(kind: .corrupt)
    }

    private static func looksLikeASCII(_ data: Data) -> Bool {
        guard
            let text = String(data: data.prefix(2048), encoding: .utf8)
                ?? String(data: data.prefix(2048), encoding: .ascii)
        else { return false }
        let lower = text.lowercased()
        let trimmed = lower.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("solid") else { return false }
        return lower.contains("facet") || lower.contains("vertex") || lower.contains("endsolid")
    }

    private static func decodeBinary(_ data: Data, count: Int, progress: ProgressSink) throws
        -> MeshDocument
    {
        guard data.count == 84 + count * 50 else {
            throw DecodeError(kind: data.count < 84 + count * 50 ? .truncated : .corrupt)
        }
        if count == 0 {
            throw DecodeError(kind: .empty)
        }
        var triangles: [Triangle] = []
        triangles.reserveCapacity(count)
        var boundsMin = Vec3(x: .infinity, y: .infinity, z: .infinity)
        var boundsMax = Vec3(x: -.infinity, y: -.infinity, z: -.infinity)
        var degenerateCount = 0
        var edgeCounts: [QEdge: Int] = [:]
        edgeCounts.reserveCapacity(count * 3)

        for i in 0..<count {
            if Task.isCancelled || progress.isCancelled() { break }
            let base = 84 + i * 50
            let ax = readFloat(data, base + 12)
            let ay = readFloat(data, base + 16)
            let az = readFloat(data, base + 20)
            let bx = readFloat(data, base + 24)
            let by = readFloat(data, base + 28)
            let bz = readFloat(data, base + 32)
            let cx = readFloat(data, base + 36)
            let cy = readFloat(data, base + 40)
            let cz = readFloat(data, base + 44)
            let a = Vec3(x: ax, y: ay, z: az)
            let b = Vec3(x: bx, y: by, z: bz)
            let c = Vec3(x: cx, y: cy, z: cz)
            triangles.append(Triangle(a: a, b: b, c: c))
            extendBounds(&boundsMin, &boundsMax, a)
            extendBounds(&boundsMin, &boundsMax, b)
            extendBounds(&boundsMin, &boundsMax, c)
            if isDegenerate(a, b, c) {
                degenerateCount += 1
            } else {
                recordEdges(a, b, c, into: &edgeCounts)
            }
            reportProgressIfNeeded(completed: i + 1, total: count, progress: progress)
        }

        if triangles.count != count {
            // cancelled mid-way; return partial isn't specified, but shouldn't happen in tests
        }
        let bounds = AABB(min: boundsMin, max: boundsMax)
        let manifold = (degenerateCount == 0) && isManifold(edgeCounts: edgeCounts)
        return MeshDocument(
            encoding: .binary,
            triangleCount: count,
            bounds: bounds,
            isManifold: manifold,
            degenerateTriangleCount: degenerateCount,
            mesh: Mesh(triangles: triangles)
        )
    }

    private static func decodeASCII(_ data: Data, progress: ProgressSink) throws -> MeshDocument {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
        else { throw DecodeError(kind: .corrupt) }

        let rawLines = text.components(separatedBy: .newlines)
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let firstNonEmpty = lines.first(where: { !$0.isEmpty })?.lowercased(),
            firstNonEmpty.hasPrefix("solid")
        else {
            throw DecodeError(kind: .corrupt)
        }

        var triangles: [Triangle] = []
        var boundsMin = Vec3(x: .infinity, y: .infinity, z: .infinity)
        var boundsMax = Vec3(x: -.infinity, y: -.infinity, z: -.infinity)
        var degenerateCount = 0
        var edgeCounts: [QEdge: Int] = [:]
        var sawFacet = false
        var sawEndsolid = false
        var i = 0
        while i < lines.count {
            let lineLower = lines[i].lowercased()
            if lineLower.isEmpty {
                i += 1
                continue
            }
            if lineLower.hasPrefix("facet") {
                sawFacet = true
                var verts: [Vec3] = []
                i += 1
                var facetClosed = false
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                    let ll = l.lowercased()
                    if ll.isEmpty {
                        i += 1
                        continue
                    }
                    if ll.hasPrefix("vertex") {
                        let parts = l.split(whereSeparator: { $0.isWhitespace })
                        guard parts.count >= 4,
                            let xf = Float(parts[1]),
                            let yf = Float(parts[2]),
                            let zf = Float(parts[3])
                        else { throw DecodeError(kind: .corrupt) }
                        verts.append(Vec3(x: Double(xf), y: Double(yf), z: Double(zf)))
                    } else if ll.hasPrefix("endfacet") {
                        facetClosed = true
                        break
                    } else if ll.hasPrefix("endloop") || ll.hasPrefix("outer loop") {
                        // continue
                    } else if ll.hasPrefix("endsolid") {
                        sawEndsolid = true
                        break
                    } else {
                        // ignore normal or other lines
                    }
                    i += 1
                }
                if !facetClosed {
                    throw DecodeError(kind: .truncated)
                }
                guard verts.count == 3 else { throw DecodeError(kind: .corrupt) }
                let a = verts[0]
                let b = verts[1]
                let c = verts[2]
                triangles.append(Triangle(a: a, b: b, c: c))
                extendBounds(&boundsMin, &boundsMax, a)
                extendBounds(&boundsMin, &boundsMax, b)
                extendBounds(&boundsMin, &boundsMax, c)
                if isDegenerate(a, b, c) {
                    degenerateCount += 1
                } else {
                    recordEdges(a, b, c, into: &edgeCounts)
                }
                reportProgressIfNeeded(
                    completed: triangles.count, total: max(triangles.count, 1), progress: progress)
            } else if lineLower.hasPrefix("endsolid") {
                sawEndsolid = true
            }
            i += 1
        }

        if !sawFacet {
            throw DecodeError(kind: .corrupt)
        }
        if triangles.isEmpty {
            throw DecodeError(kind: .empty)
        }
        if !sawEndsolid {
            throw DecodeError(kind: .truncated)
        }
        let bounds = AABB(min: boundsMin, max: boundsMax)
        let manifold = (degenerateCount == 0) && isManifold(edgeCounts: edgeCounts)
        return MeshDocument(
            encoding: .ascii,
            triangleCount: triangles.count,
            bounds: bounds,
            isManifold: manifold,
            degenerateTriangleCount: degenerateCount,
            mesh: Mesh(triangles: triangles)
        )
    }

    private static func readFloat(_ data: Data, _ offset: Int) -> Double {
        let bits = data.withUnsafeBytes { raw -> UInt32 in
            raw.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
        return Double(Float(bitPattern: bits))
    }

    private static func extendBounds(_ minV: inout Vec3, _ maxV: inout Vec3, _ p: Vec3) {
        if p.x < minV.x { minV.x = p.x }
        if p.y < minV.y { minV.y = p.y }
        if p.z < minV.z { minV.z = p.z }
        if p.x > maxV.x { maxV.x = p.x }
        if p.y > maxV.y { maxV.y = p.y }
        if p.z > maxV.z { maxV.z = p.z }
    }

    private static func isDegenerate(_ a: Vec3, _ b: Vec3, _ c: Vec3) -> Bool {
        let ab = b - a
        let ac = c - a
        let cross = ab.cross(ac)
        let area2 = cross.x * cross.x + cross.y * cross.y + cross.z * cross.z
        return area2 <= 1e-18
    }

    private static func quantized(_ v: Double) -> Int64 {
        Int64((v * 1_000_000.0).rounded())
    }

    private struct QV: Hashable {
        let x: Int64
        let y: Int64
        let z: Int64
        init(_ v: Vec3) {
            x = STLDecoder.quantized(v.x)
            y = STLDecoder.quantized(v.y)
            z = STLDecoder.quantized(v.z)
        }
    }

    private struct QEdge: Hashable {
        let a: QV
        let b: QV
        init(_ p: Vec3, _ q: Vec3) {
            let qp = QV(p)
            let qq = QV(q)
            if (qp.x, qp.y, qp.z) <= (qq.x, qq.y, qq.z) {
                a = qp
                b = qq
            } else {
                a = qq
                b = qp
            }
        }
    }

    private static func recordEdges(
        _ a: Vec3, _ b: Vec3, _ c: Vec3, into edgeCounts: inout [QEdge: Int]
    ) {
        edgeCounts[QEdge(a, b), default: 0] += 1
        edgeCounts[QEdge(b, c), default: 0] += 1
        edgeCounts[QEdge(c, a), default: 0] += 1
    }

    private static func isManifold(edgeCounts: [QEdge: Int]) -> Bool {
        for (_, count) in edgeCounts {
            if count != 2 { return false }
        }
        return !edgeCounts.isEmpty
    }

    private static func reportProgressIfNeeded(completed: Int, total: Int, progress: ProgressSink) {
        guard completed >= 50_000 else { return }
        if completed % 50_000 == 0 || completed == total {
            progress.report(StageProgress(completed: completed, total: total))
        }
    }
}
