import Foundation

public struct CutterID: Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    public var description: String { rawValue }
}

public enum CutterType: String, CaseIterable, Sendable, Codable, Equatable {
    case flat
    case ballNose
    case vBit
}

public struct Cutter: Equatable, Sendable {
    public let id: CutterID
    public let name: String
    public let type: CutterType
    public let shankDiameter: Double
    public let cuttingLength: Double
    public let fluteCount: Int
    public let feedRate: Double
    public let spindleSpeed: Double
    public let cuttingDiameter: Double?
    public let ballDiameter: Double?
    public let includedAngle: Double?
    public let tipDiameter: Double?

    public init(
        id: CutterID,
        name: String,
        type: CutterType,
        shankDiameter: Double,
        cuttingLength: Double,
        fluteCount: Int,
        feedRate: Double,
        spindleSpeed: Double,
        cuttingDiameter: Double?,
        ballDiameter: Double?,
        includedAngle: Double?,
        tipDiameter: Double?
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.shankDiameter = shankDiameter
        self.cuttingLength = cuttingLength
        self.fluteCount = fluteCount
        self.feedRate = feedRate
        self.spindleSpeed = spindleSpeed
        self.cuttingDiameter = cuttingDiameter
        self.ballDiameter = ballDiameter
        self.includedAngle = includedAngle
        self.tipDiameter = tipDiameter
    }

    public var maxCuttingExtent: Double {
        switch type {
        case .flat:
            return cuttingDiameter ?? 0
        case .ballNose:
            return ballDiameter ?? 0
        case .vBit:
            let tip = tipDiameter ?? 0
            let angle = includedAngle ?? 0
            let halfAngleRadians = (angle / 2) * .pi / 180
            return tip + 2 * cuttingLength * tan(halfAngleRadians)
        }
    }

    public func renamed(to newName: String) -> Cutter {
        Cutter(
            id: id,
            name: newName,
            type: type,
            shankDiameter: shankDiameter,
            cuttingLength: cuttingLength,
            fluteCount: fluteCount,
            feedRate: feedRate,
            spindleSpeed: spindleSpeed,
            cuttingDiameter: cuttingDiameter,
            ballDiameter: ballDiameter,
            includedAngle: includedAngle,
            tipDiameter: tipDiameter
        )
    }

    public func withFeedRate(_ newFeedRate: Double) -> Cutter {
        Cutter(
            id: id,
            name: name,
            type: type,
            shankDiameter: shankDiameter,
            cuttingLength: cuttingLength,
            fluteCount: fluteCount,
            feedRate: newFeedRate,
            spindleSpeed: spindleSpeed,
            cuttingDiameter: cuttingDiameter,
            ballDiameter: ballDiameter,
            includedAngle: includedAngle,
            tipDiameter: tipDiameter
        )
    }
}
