import SwiftUI

/// The macOS menu-bar command that opens cutter-library maintenance in its own modal (FR-056,
/// FR-072). Maintenance is never embedded in the main screen; this command is the only entry point.
///
/// The action is injected as a closure rather than a `@Binding` because the app is built with
/// Command Line Tools, where the SwiftUI property-wrapper macro plugin is unavailable.
struct CutterLibraryCommands: Commands {
    let openLibrary: () -> Void

    var body: some Commands {
        CommandMenu("Library") {
            Button("Cutter Library…") {
                openLibrary()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }
}
