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

    public init(model: MainScreenModel, cutters: [Cutter]) {
        self.model = model
        self.cutters = cutters
    }

    public var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Stored cutters are read-only here. Edit them in the cutter-library modal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if cutters.isEmpty {
                    Text("No stored cutters yet. Add one in the cutter-library modal.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .accessibilityIdentifier("cutter-panel-empty")
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
        }
        .accessibilityIdentifier("cutter-panel")
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
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel("Selected")
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
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cutter \(cutter.name), \(cutter.type.rawValue)")
        .accessibilityValue(
            isSelected
                ? "Selected, \(formatted(cutter.maxCuttingExtent)) millimetres cutting diameter"
                : "Not selected, \(formatted(cutter.maxCuttingExtent)) millimetres cutting diameter"
        )
    }

    private func formatted(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.3f", value)
    }
}
