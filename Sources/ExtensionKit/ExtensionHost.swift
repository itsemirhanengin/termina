import Foundation

/// The API surface extensions use to talk to the app.
/// A thin facade over `AppState` so extensions never depend on app internals.
@MainActor
final class ExtensionHost {
    private unowned let state: AppState

    init(state: AppState) {
        self.state = state
    }

    // MARK: Reading app state

    var activeProject: Project? { state.activeProject }
    var activeTab: TerminalTab? { state.activeTab }
    var focusedSession: TerminalSession? { state.focusedSession }
    var themes: [TerminalTheme] { state.extensions.themes }
    var activeTheme: TerminalTheme { state.activeTheme }

    // MARK: Acting on the app

    /// Types text into the focused terminal (append "\n" to run it).
    func sendText(_ text: String) {
        state.focusedSession?.sendText(text)
    }

    /// Opens the inspector showing the panel with the given id.
    func showPanel(id: String) {
        state.showPanel(id: id)
    }

    func setTheme(id: String) {
        state.activeThemeID = id
    }

    func newTab() {
        state.newTab()
    }
}
