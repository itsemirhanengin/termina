import SwiftUI

@main
struct TerminaApp: App {
    @State private var state = AppState.shared

    var body: some Scene {
        WindowGroup {
            MainWindow(state: state, tab: state.initialTab)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1180, height: 760)
        .commands {
            TerminaCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
