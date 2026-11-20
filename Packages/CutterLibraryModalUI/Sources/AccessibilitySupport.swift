import SwiftUI

/// Stable VoiceOver reading order for the cutter-library modal (FR-070).
public enum AccessibilityPriority {
    /// Reading order for validation errors.
    public static let error: Double = 100
    /// Reading order for section headers.
    public static let header: Double = 90
    /// Reading order for primary form controls.
    public static let primary: Double = 70
    /// Reading order for secondary form fields.
    public static let secondary: Double = 60
    /// Reading order for library actions such as Add and Delete.
    public static let action: Double = 50
}

/// Pure builders for cutter-library announcements (FR-070), unit-tested independently of SwiftUI.
public enum AccessibilityText {
    /// Announces a cutter's name and type in the library list.
    public static func cutterRowLabel(name: String, type: String) -> String {
        "Cutter \(name), \(type)"
    }

    /// Announces a cutter's shank and cutting lengths in millimetres.
    public static func cutterRowValue(shank: String, cut: String) -> String {
        "Shank \(shank) millimetres, cutting length \(cut) millimetres"
    }

    /// Labels the Delete action with the cutter's name.
    public static func deleteCutterLabel(_ name: String) -> String {
        "Delete \(name)"
    }

    /// Prefixes a cutter-library failure message with its source.
    public static func libraryError(_ message: String) -> String {
        "Cutter library error: \(message)"
    }

    /// Hints that a cutter field is validated before the cutter can be added.
    public static func fieldHint(for field: CutterField) -> String {
        "Enter \(field.label.lowercased()); the value is validated before the cutter can be added."
    }
}

/// Applies a visible outline to validation errors when Increase Contrast or Differentiate Without
/// Color is enabled, so an error is not communicated by red text alone (FR-071).
struct ContrastAwareError: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    func body(content: Content) -> some View {
        let needsOutline = contrast == .increased || differentiate
        return
            content
            .foregroundStyle(.red)
            .fontWeight(needsOutline ? .bold : .regular)
            .underline(needsOutline, color: .red)
    }
}
