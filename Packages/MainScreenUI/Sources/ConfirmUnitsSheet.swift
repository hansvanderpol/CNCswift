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

            Text(
                "STL files carry no units and no guaranteed axis convention. Confirm both before generating a program."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Toggle(
                "Model units are millimetres",
                isOn: Binding(
                    get: { draft.unitsAreMillimetres },
                    set: { draft.unitsAreMillimetres = $0 }
                )
            )
            .accessibilityIdentifier("confirm-units-millimetres")

            Toggle(
                "Model orientation is Z-up",
                isOn: Binding(
                    get: { draft.orientationIsZUp },
                    set: { draft.orientationIsZUp = $0 }
                )
            )
            .accessibilityIdentifier("confirm-orientation-z-up")

            VStack(alignment: .leading, spacing: 6) {
                Text("Scale to millimetres").font(.headline)
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
                    Button("Apply scale") {
                        guard let parsedScale else { return }
                        model.applyScale(parsedScale)
                    }
                    .disabled(parsedScale == nil)
                    .accessibilityIdentifier("apply-scale")
                }
                Text("Applied scale: \(formatted(model.appliedScale))")
                    .font(.caption)
                    .foregroundStyle(model.scaleConfirmed ? .green : .secondary)
                Text("No scale is inferred from the file.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") {
                    model.setUnitsSheetPresented(false)
                }
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
                .accessibilityIdentifier("confirm-units-and-orientation")
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private var parsedScale: Double? {
        guard let value = Double(draft.scaleText), value.isFinite, value > 0 else { return nil }
        return value
    }

    private func formatted(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.3f", value)
    }
}
