import CutterLibraryModalUI
import MainScreenUI
import SwiftUI

@main
struct CNCswiftApp: App {
    private let composition = AppComposition()

    /// A manual binding avoids the SwiftUI `@State` macro, which is unavailable under Command Line
    /// Tools. `AppComposition` is `@Observable`, so changes to its flag still drive presentation.
    private var cutterLibraryPresented: Binding<Bool> {
        Binding(
            get: { composition.showingCutterLibrary },
            set: { composition.showingCutterLibrary = $0 }
        )
    }

    var body: some Scene {
        WindowGroup {
            MainScreen(
                model: composition.model,
                cutters: composition.cutters,
                materials: composition.materials,
                profile: composition.profile
            )
            .task {
                await composition.loadLibraries()
            }
            .sheet(isPresented: cutterLibraryPresented) {
                LibraryModal(
                    store: composition.cutterStore,
                    libraryURL: composition.cutterURL
                )
            }
        }
        .commands {
            CutterLibraryCommands {
                composition.showingCutterLibrary = true
            }
        }
    }
}
