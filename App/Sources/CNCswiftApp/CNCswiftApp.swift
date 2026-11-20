import MainScreenUI
import SwiftUI

@main
struct CNCswiftApp: App {
    private let composition = AppComposition()

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
        }
    }
}
