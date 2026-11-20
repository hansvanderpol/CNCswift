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

            Text("Before generating")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(AccessibilityPriority.header)
            let blockers = model.blockers()
            if blockers.isEmpty {
                Label("All confirmations complete", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("generation-unblocked")
                    .accessibilitySortPriority(AccessibilityPriority.status)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(blockers, id: \.self) { blocker in
                        Label(blocker.message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .accessibilityLabel("Blocker: \(blocker.message)")
                    }
                }
                .accessibilityIdentifier("generation-blockers")
                .accessibilitySortPriority(AccessibilityPriority.findings)
            }

            ProgressView(value: progressValue)
                .accessibilityLabel("Generation progress")
                .accessibilityValue(
                    AccessibilityText.progress(
                        completed: model.progressCompleted,
                        total: model.progressTotal
                    )
                )
                .accessibilityHint("Shows how many generation stages have completed")
                .accessibilitySortPriority(AccessibilityPriority.status)

            HStack {
                Button {
                    Task { await model.startGeneration() }
                } label: {
                    Label("Generate G-code", systemImage: "gearshape.arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!blockers.isEmpty || model.generationStatus == .running)
                .accessibilityLabel("Generate G-code preview")
                .accessibilityHint("Starts a write-free generation once every blocker is cleared")
                .accessibilityIdentifier("generate-button")
                .accessibilitySortPriority(AccessibilityPriority.primary)

                if model.generationStatus == .running {
                    Button(role: .destructive) {
                        model.requestCancellation()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                    .disabled(model.isCancellationRequested)
                    .accessibilityLabel("Cancel generation")
                    .accessibilityHint("Stops the current job without writing a file")
                    .accessibilityIdentifier("cancel-generation")
                    .accessibilitySortPriority(AccessibilityPriority.primary)
                }

                Spacer()
                statusLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("generate-controls")
        .accessibilityLabel("Generation controls")
    }

    private var progressValue: Double {
        guard model.progressTotal > 0 else { return 0 }
        return Double(model.progressCompleted) / Double(model.progressTotal)
    }

    @ViewBuilder
    private var statusLabel: some View {
        // The visible wording varies by state; VoiceOver gets one stable label plus a value.
        statusView
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Generation status")
            .accessibilityValue(AccessibilityText.generationStatus(model.generationStatus))
            .accessibilitySortPriority(AccessibilityPriority.status)
    }

    @ViewBuilder
    private var statusView: some View {
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
