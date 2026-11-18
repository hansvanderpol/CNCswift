import Foundation

public enum MaterialOrigin: String, Sendable, Codable, Equatable {
    case builtIn
    case user
}

public struct MaterialBand: Equatable, Sendable {
    public let lowerBound: Double
    public let upperBound: Double

    public init(_ lowerBound: Double, _ upperBound: Double) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    public init(_ range: ClosedRange<Double>) {
        self.lowerBound = range.lowerBound
        self.upperBound = range.upperBound
    }

    public func contains(_ value: Double) -> Bool {
        value >= lowerBound && value <= upperBound
    }

    public static func == (lhs: MaterialBand, rhs: ClosedRange<Double>) -> Bool {
        lhs.lowerBound == rhs.lowerBound && lhs.upperBound == rhs.upperBound
    }

    public static func == (lhs: ClosedRange<Double>, rhs: MaterialBand) -> Bool {
        rhs == lhs
    }
}

public struct Material: Equatable, Sendable {
    public let id: String
    public let name: String
    public let feedBand: MaterialBand
    public let spindleBand: MaterialBand
    public let origin: MaterialOrigin
    public let shippedVersion: String?

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

public enum MaterialValidationError: Error, Equatable, Sendable {
    case nonPositiveBound(String)
    case invertedBand(String)
    case emptyName
    case duplicateName(String)
    case duplicateIdentifier
}

public enum MaterialValidator {
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
