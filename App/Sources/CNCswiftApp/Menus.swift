import CNCMachineProfile
import SwiftUI

/// macOS menu-bar conventions for the G-code workflow (FR-072).
///
/// The app is a single-document tool: there is no New menu item, so the standard one is removed.
/// The three generation actions are exposed once in a dedicated G-code menu with the conventional
/// shortcuts, and each calls the same main-screen model method as the on-screen controls so the
/// menu can never bypass generation blockers, cancellation, or the post-preview commit gate.
struct MainScreenCommands: Commands {
    let generate: () -> Void
    let commit: () -> Void
    let cancel: () -> Void
    let showKeyboardHelp: () -> Void
    let canCommit: Bool
    let isGenerating: Bool

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandMenu("G-code") {
            Button("Generate Preview…") {
                generate()
            }
            .keyboardShortcut("g", modifiers: [.command])
            .disabled(isGenerating)

            Button("Write G-code File…") {
                commit()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(!canCommit)

            Divider()

            Button("Cancel Generation") {
                cancel()
            }
            .keyboardShortcut(".", modifiers: [.command])
            .disabled(!isGenerating)
        }

        // Keyboard-only users can discover every workflow shortcut without a pointing device.
        CommandMenu("Accessibility") {
            Button("Keyboard Shortcuts…") {
                showKeyboardHelp()
            }
            .keyboardShortcut("?", modifiers: [.command])
        }
    }
}

/// The Settings window describing the configured machine and the app's offline guarantee
/// (FR-072, FR-074).
///
/// Controller values are shown for the operator to apply once on the machine; the app never reads
/// or changes a controller setting. Nothing in this window can transmit data.
struct CNCswiftSettings: View {
    let profile: MachineProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CNCswift").font(.title2)
                    Text("G-code creation for \(profile.displayName).")
                        .foregroundStyle(.secondary)
                }

                GroupBox("Machine profile") {
                    VStack(alignment: .leading, spacing: 4) {
                        detailRow("Machine", profile.displayName)
                        detailRow("Profile", "\(profile.profileID) (v\(profile.version))")
                        detailRow("Dialect", profile.dialect)
                        detailRow(
                            "Envelope",
                            "\(Int(profile.envelope.x)) × \(Int(profile.envelope.y)) × "
                                + "\(Int(profile.envelope.z)) mm"
                        )
                        detailRow(
                            "Feed / rapid ceiling",
                            "\(Int(profile.limits.maxFeedRate)) / "
                                + "\(Int(profile.limits.maxRapidRate)) mm/min"
                        )
                        detailRow(
                            "Spindle range",
                            "\(Int(profile.limits.spindleMin))–\(Int(profile.limits.spindleMax)) RPM"
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Controller setup (apply once on the machine)") {
                    VStack(alignment: .leading, spacing: 4) {
                        settingRows(profile.controllerSetup.rapidRate, unit: "mm/min")
                        settingRows(profile.controllerSetup.spindleBuffer, unit: "RPM")
                        Text("The app documents these settings but never reads or changes them.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Privacy") {
                    Text(
                        "Models, cutters, and generated files stay on this Mac. "
                            + "CNCswift has no network access and collects no usage data."
                    )
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .frame(width: 420)
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.callout)
    }

    @ViewBuilder
    private func settingRows(_ settings: [String: Int], unit: String) -> some View {
        ForEach(settings.keys.sorted(), id: \.self) { key in
            if let value = settings[key] {
                HStack {
                    Text(key).monospacedDigit()
                    Spacer()
                    Text("\(value) \(unit)")
                }
                .font(.callout)
            }
        }
    }
}
