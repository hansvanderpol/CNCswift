import AppKit
import CNCDiagnostics
import MainScreenUI
import SwiftUI

/// App-wide accessibility behaviour (FR-071).
///
/// The UI modules declare labels, values, roles and reading order on their controls (T104). This
/// modifier supplies what only the app can do: remove implicit animation under Reduce Motion,
/// announce generation-state changes while VoiceOver is running, and record the effective settings
/// under the `ui` diagnostic category so a support session can reproduce the operator's setup.
struct AccessibilityAdaptations: ViewModifier {
    private static let logger = DiagnosticLogger(category: .ui)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    let status: MainScreenGenerationStatus

    func body(content: Content) -> some View {
        content
            // A nil transaction animation suppresses implicit animations in the whole subtree,
            // including state-driven view transitions, without removing any functionality.
            .transaction { transaction in
                if reduceMotion {
                    transaction.animation = nil
                }
            }
            .onChange(of: reduceMotion, initial: true) { _, enabled in
                Self.logger.info("Reduce Motion \(enabled ? "on" : "off")")
            }
            .onChange(of: contrast, initial: true) { _, value in
                Self.logger.info(
                    "Display contrast \(value == .increased ? "increased" : "standard")")
            }
            .onChange(of: accessibilityEnabled, initial: true) { _, enabled in
                Self.logger.info("Accessibility \(enabled ? "on" : "off")")
            }
            .onChange(of: voiceOverEnabled, initial: true) { _, enabled in
                Self.logger.info("VoiceOver \(enabled ? "on" : "off")")
                if enabled {
                    AccessibilityNotification.Announcement("CNCswift is accessible").post()
                }
            }
            .onAppear {
                Self.logger.info(
                    "Full Keyboard Access "
                        + (NSApplication.shared.isFullKeyboardAccessEnabled ? "on" : "off")
                )
            }
            .onChange(of: status) { _, newStatus in
                guard voiceOverEnabled else { return }
                AccessibilityNotification.Announcement(
                    "Generation \(AccessibilityText.generationStatus(newStatus))"
                )
                .post()
            }
            .accessibilityIdentifier("accessibility-root")
    }
}

/// Keyboard-only reference for both primary workflows (FR-070, FR-071, SC-009).
///
/// The shortcuts are the same ones exposed by the menu commands, so this window documents rather
/// than reimplements them. It is reachable from the Accessibility menu and with `⌘?`.
struct KeyboardHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard shortcuts")
                .font(.title2)
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(AccessibilityPriority.header)

            shortcut("⌘G", "Generate a write-free G-code preview")
            shortcut("⌘S", "Write the previewed G-code file after acknowledging findings")
            shortcut("⌘.", "Cancel generation")
            shortcut("⇧⌘L", "Open the cutter library")
            shortcut("⌘?", "Show this keyboard reference")

            VStack(alignment: .leading, spacing: 4) {
                Text("In the preview, arrow keys orbit and + / − zoom. Tab moves between controls.")
                Text(
                    "Full Keyboard Access is currently "
                        + (NSApplication.shared.isFullKeyboardAccessEnabled ? "on" : "off")
                        + "."
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilitySortPriority(AccessibilityPriority.footer)
        }
        .padding(24)
        .frame(width: 460)
        .accessibilityLabel("Keyboard shortcuts")
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func shortcut(_ keys: String, _ description: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(keys)
                .font(.body.monospaced())
                .frame(width: 54, alignment: .trailing)
            Text(description)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(keys): \(description)")
        .accessibilitySortPriority(AccessibilityPriority.primary)
    }
}
