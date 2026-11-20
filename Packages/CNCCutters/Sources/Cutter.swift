import Foundation

/// A stable identifier for a cutter in the library.
///
/// - Concurrency: `Sendable` value type; safe to pass across concurrency boundaries.
public struct CutterID: Hashable, Sendable, Codable, ExpressibleByStringLiteral,
    CustomStringConvertible
{
    /// The underlying string value of the identifier.
    public let rawValue: String

    /// Creates an identifier from a raw string.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an identifier from a string literal.
    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    /// The identifier's raw string, used for its textual representation.
    public var description: String { rawValue }
}

/// The supported cutter shapes.
///
/// - Concurrency: `Sendable` value type; safe to pass across concurrency boundaries.
public enum CutterType: String, CaseIterable, Sendable, Codable, Equatable {
    /// A flat end mill.
    case flat
    /// A ball-nose cutter.
    case ballNose
    /// A V-bit cutter.
    case vBit
}

/// A complete cutter definition with its geometry, cutting parameters, and identity.
///
/// - Concurrency: `Sendable` value type; safe to pass across concurrency boundaries.
public struct Cutter: Codable, Equatable, Sendable {
    /// The stable identifier of this cutter.
    public let id: CutterID
    /// The user-visible name of the cutter.
    public let name: String
    /// The cutter's shape.
    public let type: CutterType
    /// The shank diameter in millimetres.
    public let shankDiameter: Double
    /// The usable cutting length in millimetres.
    public let cuttingLength: Double
    /// The number of flutes.
    public let fluteCount: Int
    /// The configured feed rate.
    public let feedRate: Double
    /// The configured spindle speed.
    public let spindleSpeed: Double
    /// The cutting diameter for flat cutters, or `nil` for other types.
    public let cuttingDiameter: Double?
    /// The ball diameter for ball-nose cutters, or `nil` for other types.
    public let ballDiameter: Double?
    /// The included angle in degrees for V-bits, or `nil` for other types.
    public let includedAngle: Double?
    /// The tip diameter for V-bits, or `nil` for other types.
    public let tipDiameter: Double?

    /// Creates a cutter with the supplied identity, geometry, and cutting parameters.
    ///
    /// Type-specific fields should match `type`; use `CutterValidator` to enforce the
    /// relationship and the accepted ranges.
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

    /// The maximum cutting width implied by the cutter type and its dimensions.
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

    /// Returns a copy of this cutter with a new name, preserving its identity.
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

    /// Returns a copy of this cutter with a new feed rate, preserving its identity.
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
