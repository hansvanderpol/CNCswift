import Foundation

/// Reasons a cutter definition can fail validation.
///
/// - Concurrency: `Sendable` error value; safe to pass across concurrency boundaries.
public enum CutterValidationError: Error, Equatable, Sendable {
    /// A field required for the cutter type is absent.
    case missingField(String)
    /// A field that must be absent for the cutter type is present.
    case forbiddenField(String)
    /// A dimension is negative, or zero where a positive value is required.
    case nonPositive(String)
    /// The flute count is outside the supported range.
    case invalidFluteCount
    /// The feed rate is outside the supported range.
    case feedOutOfRange
    /// The spindle speed is outside the supported range.
    case spindleOutOfRange
    /// The cutter's name is empty or whitespace only.
    case emptyName
    /// The shank is narrower than the required cutting extent.
    case shankTooSmall(required: Double)
    /// The V-bit included angle is not within the supported range.
    case invalidAngle
}

/// Validates cutter definitions against the machine's accepted ranges.
public enum CutterValidator {
    /// Checks a cutter's name, dimensions, settings, and type-specific fields.
    ///
    /// - Throws: `CutterValidationError` for an empty name, non-positive or out-of-range
    ///   dimensions, a flute count outside 1...8, feed or spindle outside their ranges,
    ///   missing or forbidden type-specific fields, an invalid V-bit angle or tip, or a
    ///   shank narrower than the cutting extent.
    public static func validate(_ cutter: Cutter) throws {
        guard !cutter.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CutterValidationError.emptyName
        }
        guard cutter.shankDiameter > 0 else {
            throw CutterValidationError.nonPositive("shankDiameter")
        }
        guard cutter.cuttingLength > 0 else {
            throw CutterValidationError.nonPositive("cuttingLength")
        }
        guard (1...8).contains(cutter.fluteCount) else {
            throw CutterValidationError.invalidFluteCount
        }
        guard cutter.feedRate > 0, cutter.feedRate <= 800 else {
            throw CutterValidationError.feedOutOfRange
        }
        guard cutter.spindleSpeed >= 5000, cutter.spindleSpeed <= 8000 else {
            throw CutterValidationError.spindleOutOfRange
        }

        switch cutter.type {
        case .flat:
            guard let diameter = cutter.cuttingDiameter else {
                throw CutterValidationError.missingField("cuttingDiameter")
            }
            guard diameter > 0 else {
                throw CutterValidationError.nonPositive("cuttingDiameter")
            }
            try rejectForbidden(cutter.ballDiameter, "ballDiameter")
            try rejectForbidden(cutter.includedAngle, "includedAngle")
            try rejectForbidden(cutter.tipDiameter, "tipDiameter")
        case .ballNose:
            guard let diameter = cutter.ballDiameter else {
                throw CutterValidationError.missingField("ballDiameter")
            }
            guard diameter > 0 else {
                throw CutterValidationError.nonPositive("ballDiameter")
            }
            try rejectForbidden(cutter.cuttingDiameter, "cuttingDiameter")
            try rejectForbidden(cutter.includedAngle, "includedAngle")
            try rejectForbidden(cutter.tipDiameter, "tipDiameter")
        case .vBit:
            guard let angle = cutter.includedAngle else {
                throw CutterValidationError.missingField("includedAngle")
            }
            guard let tip = cutter.tipDiameter else {
                throw CutterValidationError.missingField("tipDiameter")
            }
            guard angle > 0, angle < 180 else {
                throw CutterValidationError.invalidAngle
            }
            guard tip >= 0 else {
                throw CutterValidationError.nonPositive("tipDiameter")
            }
            guard tip <= cutter.shankDiameter else {
                throw CutterValidationError.shankTooSmall(required: tip)
            }
            try rejectForbidden(cutter.cuttingDiameter, "cuttingDiameter")
            try rejectForbidden(cutter.ballDiameter, "ballDiameter")
        }

        let requiredShank = cutter.maxCuttingExtent
        guard cutter.shankDiameter >= requiredShank else {
            throw CutterValidationError.shankTooSmall(required: requiredShank)
        }
    }

    private static func rejectForbidden(_ value: Double?, _ name: String) throws {
        if value != nil {
            throw CutterValidationError.forbiddenField(name)
        }
    }
}
