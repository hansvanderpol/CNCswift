import SwiftUI

/// Stable VoiceOver reading order for the cutter-library modal (FR-070).
public enum AccessibilityPriority {
    public static let error: Double = 100
    public static let header: Double = 90
    public static let primary: Double = 70
    public static let secondary: Double = 60
    public static let action: Double = 50
}

/// Pure builders for cutter-library announcements (FR-070), unit-tested independently of SwiftUI.
public enum AccessibilityText {
    public static func cutterRowLabel(name: String, type: String) -> String {
        "Cutter \(name), \(type)"
    }

    public static func cutterRowValue(shank: String, cut: String) -> String {
        "Shank \(shank) millimetres, cutting length \(cut) millimetres"
    }

    public static func deleteCutterLabel(_ name: String) -> String {
        "Delete \(name)"
    }

    public static func libraryError(_ message: String) -> String {
        "Cutter library error: \(message)"
    }

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
