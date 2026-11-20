import CNCCutters
import Foundation
import Observation

/// The input fields of a cutter editor form.
///
/// A field's raw value is its persisted key, which is what validation messages name (FR-048).
///
/// - Concurrency: Sendable value; safe to pass across tasks.
public enum CutterField: String, CaseIterable, Sendable, Hashable {
    case name
    case shankDiameter
    case cuttingLength
    case fluteCount
    case feedRate
    case spindleSpeed
    case cuttingDiameter
    case ballDiameter
    case includedAngle
    case tipDiameter

    /// A human-readable label for the field in the form and in accessibility metadata.
    public var label: String {
        switch self {
        case .name: return "Name"
        case .shankDiameter: return "Shank diameter (mm)"
        case .cuttingLength: return "Cutting length (mm)"
        case .fluteCount: return "Flute count"
        case .feedRate: return "Feed rate (mm/min)"
        case .spindleSpeed: return "Spindle speed (RPM)"
        case .cuttingDiameter: return "Cutting diameter (mm)"
        case .ballDiameter: return "Ball diameter (mm)"
        case .includedAngle: return "Included angle (degrees)"
        case .tipDiameter: return "Tip diameter (mm)"
        }
    }
}

/// Form state and entry-time validation for one cutter (FR-044 – FR-048).
///
/// The model owns only text fields for one record. It never touches the store: a caller uses
/// `makeCutter()` and hands the resulting value to a coordinator. Every error is computed from
/// the current field text so the UI can name the broken rule and its limit before saving.
///
/// - Concurrency: Main-actor isolated; observed directly by SwiftUI.
@Observable
@MainActor
public final class CutterEditorModel {
    /// The cutter type whose dimension fields are requested by `requiredFields()`.
    ///
    /// - Concurrency: Main-actor isolated observable state.
    public var type: CutterType

    /// Raw text entered by the user, keyed by field.
    ///
    /// - Concurrency: Main-actor isolated observable state.
    public var fields: [CutterField: String]

    /// Creates an editor with the given type and initial field text.
    public init(type: CutterType = .flat, fields: [CutterField: String] = [:]) {
        self.type = type
        self.fields = fields
    }

    /// The fields required for the selected type; forbidden fields are never requested.
    public func requiredFields() -> [CutterField] {
        var result: [CutterField] = [
            .name, .shankDiameter, .cuttingLength, .fluteCount, .feedRate, .spindleSpeed,
        ]
        switch type {
        case .flat:
            result.append(.cuttingDiameter)
        case .ballNose:
            result.append(.ballDiameter)
        case .vBit:
            result.append(contentsOf: [.includedAngle, .tipDiameter])
        }
        return result
    }

    /// A message naming the broken rule and its limit, or `nil` when the field is acceptable.
    ///
    /// A field belonging to another cutter type is rejected when it carries a value; an empty
    /// forbidden field is ignored. This prevents another type's dimension being borrowed as a
    /// substitute for the required one (FR-046).
    public func fieldError(_ field: CutterField) -> String? {
        if isForbidden(field) {
            return hasValue(field)
                ? "\(field.rawValue) is not valid for a \(type.rawValue) cutter."
                : nil
        }
        guard requiredFields().contains(field) else { return nil }

        switch field {
        case .name:
            return trimmed(field).isEmpty ? "Name is required." : nil

        case .fluteCount:
            guard let value = Int(trimmed(field)), (1...8).contains(value) else {
                return "Flute count must be between 1 and 8."
            }
            return nil

        case .feedRate:
            guard let value = number(field), value > 0, value <= 800 else {
                return "Feed rate must be greater than 0 and at most 800 mm/min."
            }
            return nil

        case .spindleSpeed:
            guard let value = number(field), value >= 5000, value <= 8000 else {
                return "Spindle speed must be between 5,000 and 8,000 RPM."
            }
            return nil

        case .shankDiameter:
            guard let value = number(field), value > 0 else {
                return "shankDiameter must be greater than zero."
            }
            if let extent = maximumCuttingExtent(), value < extent {
                return String(
                    format: "Shank diameter must be at least the maximum cutting extent (%.3f mm).",
                    extent
                )
            }
            return nil

        case .cuttingLength, .cuttingDiameter, .ballDiameter:
            guard let value = number(field), value > 0 else {
                return "\(field.rawValue) must be greater than zero."
            }
            return nil

        case .includedAngle:
            guard let value = number(field), value > 0, value < 180 else {
                return "Included angle must be greater than 0 and less than 180 degrees."
            }
            return nil

        case .tipDiameter:
            guard let value = number(field), value >= 0 else {
                return "Tip diameter must be at least 0 mm."
            }
            if let shank = number(.shankDiameter), value > shank {
                return "Tip diameter must not exceed the shank diameter."
            }
            return nil
        }
    }

    /// Builds a cutter from the current fields and applies the canonical entry validation.
    ///
    /// - Throws: `CutterValidationError` naming the first broken rule; nothing is persisted.
    public func makeCutter() throws -> Cutter {
        let cutter = Cutter(
            id: CutterID(UUID().uuidString),
            name: trimmed(.name),
            type: type,
            shankDiameter: number(.shankDiameter) ?? 0,
            cuttingLength: number(.cuttingLength) ?? 0,
            fluteCount: Int(trimmed(.fluteCount)) ?? 0,
            feedRate: number(.feedRate) ?? 0,
            spindleSpeed: number(.spindleSpeed) ?? 0,
            cuttingDiameter: number(.cuttingDiameter),
            ballDiameter: number(.ballDiameter),
            includedAngle: number(.includedAngle),
            tipDiameter: number(.tipDiameter)
        )
        try CutterValidator.validate(cutter)
        return cutter
    }

    private func isForbidden(_ field: CutterField) -> Bool {
        switch type {
        case .flat:
            return field == .ballDiameter || field == .includedAngle || field == .tipDiameter
        case .ballNose:
            return field == .cuttingDiameter || field == .includedAngle || field == .tipDiameter
        case .vBit:
            return field == .cuttingDiameter || field == .ballDiameter
        }
    }

    private func trimmed(_ field: CutterField) -> String {
        (fields[field] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasValue(_ field: CutterField) -> Bool {
        !trimmed(field).isEmpty
    }

    private func number(_ field: CutterField) -> Double? {
        let text = trimmed(field)
        return text.isEmpty ? nil : Double(text)
    }

    private func maximumCuttingExtent() -> Double? {
        switch type {
        case .flat:
            return number(.cuttingDiameter)
        case .ballNose:
            return number(.ballDiameter)
        case .vBit:
            guard let tip = number(.tipDiameter),
                let angle = number(.includedAngle),
                let length = number(.cuttingLength),
                angle > 0, angle < 180
            else { return nil }
            return tip + 2 * length * tan((angle / 2) * .pi / 180)
        }
    }
}
