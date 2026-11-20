import SwiftUI

/// Stable VoiceOver reading order for the main screen (FR-070). SwiftUI reads higher priorities
/// first, so the three panels and their status are announced in the order an operator uses them.
public enum AccessibilityPriority {
    public static let header: Double = 100
    public static let findings: Double = 90
    public static let primary: Double = 70
    public static let secondary: Double = 60
    public static let status: Double = 50
    public static let navigation: Double = 40
    public static let footer: Double = 30
}

/// Pure builders for the strings VoiceOver announces. Keeping them out of the views lets unit tests
/// check that a state change is actually described, not merely that a modifier was attached.
public enum AccessibilityText {
    public static func cutterLabel(name: String, type: String) -> String {
        "Cutter \(name), \(type)"
    }

    public static func cutterValue(
        isSelected: Bool,
        diameter: String,
        feed: String,
        spindle: String
    ) -> String {
        let state = isSelected ? "Selected" : "Not selected"
        return "\(state), \(diameter) millimetres cutting diameter, "
            + "\(feed) millimetres per minute, \(spindle) RPM"
    }

    public static func stockFieldLabel(_ dimension: String) -> String {
        "Stock \(dimension) in millimetres"
    }

    public static func stockFieldHint(_ dimension: String) -> String {
        "Enter a positive \(dimension.lowercased()) in millimetres"
    }

    public static func progress(completed: Int, total: Int) -> String {
        "\(completed) of \(max(1, total)) stages"
    }

    public static func generationStatus(_ status: MainScreenGenerationStatus) -> String {
        switch status {
        case .idle:
            return "Idle"
        case .running:
            return "Generating"
        case .ready:
            return "Ready to preview"
        case .blocked(let messages):
            return "Blocked: \(messages.joined(separator: "; "))"
        case .cancelled:
            return "Cancelled"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }
}

/// Adds a non-colour selection indicator when Increase Contrast or Differentiate Without Color is
/// enabled (FR-071). A translucent accent tint alone is not distinguishable in those modes.
struct ContrastAwareSelection: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    let isSelected: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let outlined = isSelected && (contrast == .increased || differentiate)
        return
            content
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(outlined ? Color.accentColor : Color.clear, lineWidth: 2)
            }
    }
}
