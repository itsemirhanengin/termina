import AppKit
import SwiftUI

@main
struct TerminaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // No WindowGroup: every terminal window is created by
        // `NativeWindowCoordinator` so they are all `TerminaWindow`s and all
        // behave identically. A SwiftUI-owned window would answer the tab
        // bar's "+" itself and clone the scene instead of opening a new tab.
        Settings {
            SettingsView()
        }
        .commands {
            TerminaCommands()
        }
    }
}

/// Opens the first window and keeps the app alive the way a terminal should.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.openInitialWindow()
    }

    @MainActor
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            AppState.shared.openInitialWindow()
        }
        return true
    }

    /// Terminal.app semantics: closing the last window leaves the app running,
    /// ready to open a new one from the dock or ⌘N.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
