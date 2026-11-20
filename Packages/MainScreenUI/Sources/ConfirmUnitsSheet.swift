import SwiftUI

/// The units, orientation, and explicit-scale confirmation sheet (FR-005, FR-006).
///
/// Nothing is assumed from an STL file: the operator must affirm millimetres and Z-up orientation,
/// then apply a positive scale explicitly before confirmation is allowed.
@MainActor
public struct ConfirmUnitsSheet: View {
    private let model: MainScreenModel
    private let draft: UnitsConfirmationDraft

    public init(model: MainScreenModel, draft: UnitsConfirmationDraft) {
        self.model = model
        self.draft = draft
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm model units and orientation")
                .font(.title2)
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(AccessibilityPriority.header)

            Text(
                "STL files carry no units and no guaranteed axis convention. Confirm both before generating a program."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilitySortPriority(AccessibilityPriority.secondary)

            Toggle(
                "Model units are millimetres",
                isOn: Binding(
                    get: { draft.unitsAreMillimetres },
                    set: { draft.unitsAreMillimetres = $0 }
                )
            )
            .accessibilityLabel("Model units are millimetres")
            .accessibilityValue(draft.unitsAreMillimetres ? "Confirmed" : "Not confirmed")
            .accessibilityHint("STL files do not carry units; confirm this before generating")
            .accessibilityIdentifier("confirm-units-millimetres")
            .accessibilitySortPriority(AccessibilityPriority.primary)

            Toggle(
                "Model orientation is Z-up",
                isOn: Binding(
                    get: { draft.orientationIsZUp },
                    set: { draft.orientationIsZUp = $0 }
                )
            )
            .accessibilityLabel("Model orientation is Z-up")
            .accessibilityValue(draft.orientationIsZUp ? "Confirmed" : "Not confirmed")
            .accessibilityHint("Confirm the model's Z axis points up")
            .accessibilityIdentifier("confirm-orientation-z-up")
            .accessibilitySortPriority(AccessibilityPriority.primary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Scale to millimetres")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilitySortPriority(AccessibilityPriority.secondary)
                HStack {
                    TextField(
                        "e.g. 1",
                        text: Binding(
                            get: { draft.scaleText },
                            set: { draft.scaleText = $0 }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .accessibilityLabel("Scale to millimetres")
                    .accessibilityValue(draft.scaleText)
                    .accessibilityHint("Enter a positive scale factor, then apply it")
                    .accessibilitySortPriority(AccessibilityPriority.primary)
                    Button("Apply scale") {
                        guard let parsedScale else { return }
                        model.applyScale(parsedScale)
                    }
                    .disabled(parsedScale == nil)
                    .accessibilityHint(
                        "Applies the entered scale without inferring one from the file"
                    )
                    .accessibilityIdentifier("apply-scale")
                    .accessibilitySortPriority(AccessibilityPriority.primary)
                }
                Text("Applied scale: \(formatted(model.appliedScale))")
                    .font(.caption)
                    .foregroundStyle(model.scaleConfirmed ? .green : .secondary)
                    .accessibilityLabel("Applied scale")
                    .accessibilityValue(
                        "\(formatted(model.appliedScale)), \(model.scaleConfirmed ? "confirmed" : "not confirmed")"
                    )
                    .accessibilitySortPriority(AccessibilityPriority.status)
                Text("No scale is inferred from the file.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilitySortPriority(AccessibilityPriority.footer)
            }

            HStack {
                Button("Cancel") {
                    model.setUnitsSheetPresented(false)
                }
                .accessibilityHint("Returns to the main screen without confirming")
                .accessibilitySortPriority(AccessibilityPriority.footer)
                Spacer()
                Button("Confirm units and orientation") {
                    model.confirmUnitsAndOrientation(
                        units: draft.unitsAreMillimetres,
                        orientation: draft.orientationIsZUp
                    )
                    model.setUnitsSheetPresented(false)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    !draft.unitsAreMillimetres || !draft.orientationIsZUp || !model.scaleConfirmed
                )
                .accessibilityHint("Confirms millimetres, Z-up, and the applied scale")
                .accessibilityIdentifier("confirm-units-and-orientation")
                .accessibilitySortPriority(AccessibilityPriority.primary)
            }
        }
        .padding(24)
        .frame(width: 460)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Confirm units and orientation")
    }

    private var parsedScale: Double? {
        guard let value = Double(draft.scaleText), value.isFinite, value > 0 else { return nil }
        return value
    }

    private func formatted(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.3f", value)
    }
}
