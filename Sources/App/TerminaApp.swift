import AppKit
import SwiftUI

@main
struct TerminaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // No WindowGroup: the single terminal window is created by
        // `MainWindowController`, so the app — not SwiftUI — decides when it
        // exists and what it contains.
        Settings {
            SettingsView()
        }
        .commands {
            TerminaCommands()
        }
    }
}

/// Opens the window and keeps the app alive the way a terminal should.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainWindowController.shared.show(state: .shared)
    }

    @MainActor
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            MainWindowController.shared.show(state: .shared)
        }
        return true
    }

    /// Terminal.app semantics: closing the window leaves the app running,
    /// ready to open a new one from the dock.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
