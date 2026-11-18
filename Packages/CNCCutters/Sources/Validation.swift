import Foundation

public enum CutterValidationError: Error, Equatable, Sendable {
    case missingField(String)
    case forbiddenField(String)
    case nonPositive(String)
    case invalidFluteCount
    case feedOutOfRange
    case spindleOutOfRange
    case emptyName
    case shankTooSmall(required: Double)
    case invalidAngle
}

public enum CutterValidator {
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
