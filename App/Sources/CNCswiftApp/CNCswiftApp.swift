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

    // `RealityKit.Scene` is also in the module graph through MainScreenUI; qualify SwiftUI's
    // scene protocol so the app scene cannot bind to the rendering type (D3).
    var body: some SwiftUI.Scene {
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
