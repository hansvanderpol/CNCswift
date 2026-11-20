import SwiftUI

/// Generate, progress, and cancellation controls plus the pre-generation checklist (FR-037,
/// FR-040, FR-069).
///
/// These controls live in the job panel's footer so the main screen keeps exactly three panels.
@MainActor
public struct GenerateControls: View {
    private let model: MainScreenModel

    public init(model: MainScreenModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            Text("Before generating").font(.headline)
            let blockers = model.blockers()
            if blockers.isEmpty {
                Label("All confirmations complete", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("generation-unblocked")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(blockers, id: \.self) { blocker in
                        Label(blocker.message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                    }
                }
                .accessibilityIdentifier("generation-blockers")
            }

            ProgressView(value: progressValue)
                .accessibilityLabel("Generation progress")
                .accessibilityValue(
                    "\(model.progressCompleted) of \(max(1, model.progressTotal)) stages")

            HStack {
                Button {
                    Task { await model.startGeneration() }
                } label: {
                    Label("Generate G-code", systemImage: "gearshape.arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!blockers.isEmpty || model.generationStatus == .running)
                .accessibilityIdentifier("generate-button")

                if model.generationStatus == .running {
                    Button(role: .destructive) {
                        model.requestCancellation()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                    .disabled(model.isCancellationRequested)
                    .accessibilityIdentifier("cancel-generation")
                }

                Spacer()
                statusLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("generate-controls")
    }

    private var progressValue: Double {
        guard model.progressTotal > 0 else { return 0 }
        return Double(model.progressCompleted) / Double(model.progressTotal)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch model.generationStatus {
        case .idle:
            Text("Idle").font(.caption).foregroundStyle(.secondary)
        case .running:
            Label("Generating…", systemImage: "progress.indicator")
                .font(.caption)
        case .ready:
            Label("Ready to preview", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.green)
        case .blocked(let messages):
            Label(
                "Blocked: \(messages.joined(separator: "; "))",
                systemImage: "exclamationmark.octagon"
            )
            .font(.caption)
            .foregroundStyle(.red)
        case .cancelled:
            Label("Cancelled", systemImage: "xmark.circle")
                .font(.caption)
                .foregroundStyle(.orange)
        case .failed(let message):
            Label("Failed: \(message)", systemImage: "xmark.octagon")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
