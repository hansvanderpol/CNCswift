import CNCCutters
import SwiftUI

/// The per-type cutter form (FR-045, FR-046, FR-047).
///
/// Only the fields requested by `CutterEditorModel.requiredFields()` are shown, so a flat cutter
/// cannot borrow a ball diameter or a V-bit angle as a substitute for its own dimension.
@MainActor
public struct CutterEditor: View {
    private let model: CutterEditorModel

    /// Creates the form bound to `model` and its text fields.
    public init(model: CutterEditorModel) {
        self.model = model
    }

    /// The type picker, required fields, and the first validation error.
    public var body: some View {
        Form {
            Section("Cutter type") {
                Picker(
                    "Type",
                    selection: Binding(
                        get: { model.type },
                        set: { model.type = $0 }
                    )
                ) {
                    ForEach(CutterType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .accessibilityLabel("Cutter type")
                .accessibilityHint("Chooses which dimension fields are required")
                .accessibilityIdentifier("cutter-type-picker")
                .accessibilitySortPriority(AccessibilityPriority.header)
            }

            Section("Dimensions and starting values") {
                ForEach(model.requiredFields(), id: \.self) { field in
                    fieldRow(field)
                }
            }

            if let firstError = firstError() {
                Text(firstError)
                    .font(.caption)
                    .modifier(ContrastAwareError())
                    .accessibilityLabel("Cutter error: \(firstError)")
                    .accessibilityIdentifier("cutter-editor-first-error")
                    .accessibilitySortPriority(AccessibilityPriority.error)
            }
        }
        .accessibilityIdentifier("cutter-editor")
    }

    @ViewBuilder
    private func fieldRow(_ field: CutterField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(
                field.label,
                text: Binding(
                    get: { model.fields[field] ?? "" },
                    set: { model.fields[field] = $0 }
                )
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(field.label)
            .accessibilityValue(model.fields[field] ?? "")
            .accessibilityHint(AccessibilityText.fieldHint(for: field))
            .accessibilityIdentifier("cutter-field-\(field.rawValue)")
            .accessibilitySortPriority(AccessibilityPriority.secondary)

            if let error = model.fieldError(field) {
                Text(error)
                    .font(.caption)
                    .modifier(ContrastAwareError())
                    .accessibilityLabel("\(field.label) error: \(error)")
                    .accessibilityIdentifier("cutter-field-error-\(field.rawValue)")
                    .accessibilitySortPriority(AccessibilityPriority.error)
            }
        }
    }

    private func firstError() -> String? {
        for field in model.requiredFields() {
            if let error = model.fieldError(field) {
                return "\(field.label): \(error)"
            }
        }
        return nil
    }
}
