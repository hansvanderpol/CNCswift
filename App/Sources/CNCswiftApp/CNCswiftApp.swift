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

    private var keyboardHelpPresented: Binding<Bool> {
        Binding(
            get: { composition.showingKeyboardHelp },
            set: { composition.showingKeyboardHelp = $0 }
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
            .sheet(isPresented: keyboardHelpPresented) {
                KeyboardHelpView()
            }
            .modifier(
                AccessibilityAdaptations(status: composition.model.generationStatus)
            )
        }
        .defaultSize(width: 1120, height: 720)
        .restorationBehavior(.automatic)
        .commands {
            MainScreenCommands(
                generate: {
                    Task { @MainActor in
                        _ = await composition.model.startGeneration()
                    }
                },
                commit: {
                    Task { @MainActor in
                        _ = await composition.model.commitProgram()
                    }
                },
                cancel: {
                    composition.model.requestCancellation()
                },
                showKeyboardHelp: {
                    composition.showingKeyboardHelp = true
                },
                canCommit: composition.model.simulation.canWrite,
                isGenerating: composition.model.generationStatus == .running
            )
            CutterLibraryCommands {
                composition.showingCutterLibrary = true
            }
        }

        Settings {
            CNCswiftSettings(profile: composition.profile)
        }
    }
}
