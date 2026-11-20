import Foundation

/// Whether a material was shipped with the app or added by the user.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public enum MaterialOrigin: String, Sendable, Codable, Equatable {
    /// A material shipped with the app.
    case builtIn
    /// A material added by the user.
    case user
}

/// An inclusive feed or spindle range for a material, in mm/min or RPM.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public struct MaterialBand: Codable, Equatable, Sendable {
    /// The inclusive lower bound of the band.
    public let lowerBound: Double
    /// The inclusive upper bound of the band.
    public let upperBound: Double

    /// Creates a band from explicit lower and upper bounds.
    ///
    /// - Precondition: Both bounds are positive and ordered for a valid material.
    public init(_ lowerBound: Double, _ upperBound: Double) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    /// Creates a band from a closed range.
    ///
    /// - Precondition: The range bounds are positive and ordered for a valid material.
    public init(_ range: ClosedRange<Double>) {
        self.lowerBound = range.lowerBound
        self.upperBound = range.upperBound
    }

    /// Returns `true` when `value` lies within the inclusive band.
    public func contains(_ value: Double) -> Bool {
        value >= lowerBound && value <= upperBound
    }

    /// Compares a band with a closed range by their bounds.
    public static func == (lhs: MaterialBand, rhs: ClosedRange<Double>) -> Bool {
        lhs.lowerBound == rhs.lowerBound && lhs.upperBound == rhs.upperBound
    }

    /// Compares a closed range with a band by their bounds.
    public static func == (lhs: ClosedRange<Double>, rhs: MaterialBand) -> Bool {
        rhs == lhs
    }
}

/// A feed and spindle band paired with its identity and provenance.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public struct Material: Codable, Equatable, Sendable {
    /// The stable identifier of the material.
    public let id: String
    /// The display name of the material.
    public let name: String
    /// The allowed feed range in mm/min.
    public let feedBand: MaterialBand
    /// The allowed spindle range in RPM.
    public let spindleBand: MaterialBand
    /// Whether the material ships with the app or was added by the user.
    public let origin: MaterialOrigin
    /// An optional version tag for shipped materials.
    public let shippedVersion: String?

    /// Creates a material from closed feed and spindle ranges.
    ///
    /// - Precondition: The ranges have positive, ordered bounds.
    public init(
        id: String,
        name: String,
        feedBand: ClosedRange<Double>,
        spindleBand: ClosedRange<Double>,
        origin: MaterialOrigin,
        shippedVersion: String?
    ) {
        self.id = id
        self.name = name
        self.feedBand = MaterialBand(feedBand)
        self.spindleBand = MaterialBand(spindleBand)
        self.origin = origin
        self.shippedVersion = shippedVersion
    }

    /// Creates a material from feed and spindle bands.
    ///
    /// - Precondition: The bands have positive, ordered bounds.
    public init(
        id: String,
        name: String,
        feedBand: MaterialBand,
        spindleBand: MaterialBand,
        origin: MaterialOrigin,
        shippedVersion: String?
    ) {
        self.id = id
        self.name = name
        self.feedBand = feedBand
        self.spindleBand = spindleBand
        self.origin = origin
        self.shippedVersion = shippedVersion
    }
}

/// Reasons a material definition was rejected as invalid.
///
/// - Concurrency: `Sendable` error value; safe to share across concurrency boundaries.
public enum MaterialValidationError: Error, Equatable, Sendable {
    /// A named band has a non-positive bound.
    case nonPositiveBound(String)
    /// A named band has a lower bound above its upper bound.
    case invertedBand(String)
    /// The material name is empty after trimming whitespace.
    case emptyName
    /// Another material already uses this name.
    case duplicateName(String)
    /// Another material already uses this identifier.
    case duplicateIdentifier
}

/// Validates material definitions against the library.
public enum MaterialValidator {
    /// Validates one material and throws when any rule fails.
    ///
    /// - Parameters:
    ///   - material: The material to check.
    ///   - existing: Materials already in the library, checked for duplicates.
    /// - Throws: `MaterialValidationError` for an empty name, non-positive or inverted
    ///   bands, or a duplicate name or identifier.
    public static func validate(_ material: Material, against existing: [Material]) throws {
        let trimmedName = material.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw MaterialValidationError.emptyName
        }

        guard material.feedBand.lowerBound > 0, material.feedBand.upperBound > 0 else {
            throw MaterialValidationError.nonPositiveBound("feedBand")
        }
        guard material.spindleBand.lowerBound > 0, material.spindleBand.upperBound > 0 else {
            throw MaterialValidationError.nonPositiveBound("spindleBand")
        }
        guard material.feedBand.lowerBound <= material.feedBand.upperBound else {
            throw MaterialValidationError.invertedBand("feedBand")
        }
        guard material.spindleBand.lowerBound <= material.spindleBand.upperBound else {
            throw MaterialValidationError.invertedBand("spindleBand")
        }

        for other in existing {
            if other.name == material.name {
                throw MaterialValidationError.duplicateName(material.name)
            }
            if other.id == material.id {
                throw MaterialValidationError.duplicateIdentifier
            }
        }
    }
}
