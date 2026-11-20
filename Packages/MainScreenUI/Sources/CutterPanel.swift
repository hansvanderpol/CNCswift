import CNCCutters
import SwiftUI

/// The read-only cutter-selection panel (FR-043, FR-055).
///
/// Cutter maintenance lives in the separate modal module; this panel only lists values already
/// persisted by the Foundational store and records the operator's selection as an identifier.
@MainActor
public struct CutterPanel: View {
    private let model: MainScreenModel
    private let cutters: [Cutter]

    /// Creates a panel that lists `cutters` and records selections in `model`.
    public init(model: MainScreenModel, cutters: [Cutter]) {
        self.model = model
        self.cutters = cutters
    }

    /// The stored-cutter list, or a message when no cutters are stored.
    public var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Stored cutters are read-only here. Edit them in the cutter-library modal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if cutters.isEmpty {
                    Text("No stored cutters yet. Add one in the cutter-library modal.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .accessibilityLabel(
                            "No stored cutters. Add one in the cutter-library modal."
                        )
                        .accessibilityIdentifier("cutter-panel-empty")
                        .accessibilitySortPriority(AccessibilityPriority.primary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(cutters, id: \.id) { cutter in
                                cutterButton(cutter)
                            }
                        }
                    }
                    .accessibilityIdentifier("cutter-panel-list")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } label: {
            Label("Cutter selection", systemImage: "wrench.and.screwdriver")
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(AccessibilityPriority.header)
        }
        .accessibilityIdentifier("cutter-panel")
        .accessibilityLabel("Cutter selection")
    }

    @ViewBuilder
    private func cutterButton(_ cutter: Cutter) -> some View {
        let isSelected = model.selectedCutterID == cutter.id
        Button {
            model.selectCutter(cutter.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(cutter.name)
                        .font(.headline)
                    Spacer()
                    if isSelected {
                        // The button's value already announces the selected state.
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    }
                }
                Text(
                    "\(cutter.type.rawValue) · \(formatted(cutter.maxCuttingExtent)) mm cutting diameter"
                )
                .font(.caption)
                Text("\(formatted(cutter.feedRate)) mm/min · \(formatted(cutter.spindleSpeed)) RPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .modifier(ContrastAwareSelection(isSelected: isSelected, cornerRadius: 8))
        .accessibilityLabel(
            AccessibilityText.cutterLabel(name: cutter.name, type: cutter.type.rawValue)
        )
        .accessibilityValue(
            AccessibilityText.cutterValue(
                isSelected: isSelected,
                diameter: formatted(cutter.maxCuttingExtent),
                feed: formatted(cutter.feedRate),
                spindle: formatted(cutter.spindleSpeed)
            )
        )
        .accessibilityHint("Selects this cutter for the current job")
        .accessibilityAddTraits(.isButton)
        .accessibilitySortPriority(AccessibilityPriority.primary)
    }

    private func formatted(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.3f", value)
    }
}
