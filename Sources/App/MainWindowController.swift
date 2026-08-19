import AppKit
import SwiftUI

/// Owns the app's single window.
///
/// Tabs used to be real `NSWindow`s in a native tab group. They are now part
/// of the workspace model instead, because a native tab group belongs to a
/// window and cannot be swapped when the sidebar selects another project.
@MainActor
final class MainWindowController {
    static let shared = MainWindowController()

    private var controller: NSWindowController?

    private init() {}

    var isOpen: Bool { controller?.window != nil }

    func show(state: AppState) {
        if let controller, let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(rootView: MainWindow(state: state))
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 1180, height: 760))
        window.minSize = NSSize(width: 820, height: 500)
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unified
        window.titleVisibility = .visible
        window.titlebarSeparatorStyle = .automatic
        // Tabs live in the workspace now; macOS must not add its own.
        window.tabbingMode = .disallowed

        let controller = NSWindowController(window: window)
        self.controller = controller
        window.setFrameAutosaveName("com.itsemirhanengin.termina.main")
        if window.frame.origin == .zero { window.center() }
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    /// Keeps the titlebar in step with the selected project and tab.
    func updateTitle(_ title: String, subtitle: String) {
        guard let window = controller?.window else { return }
        window.title = title
        window.subtitle = subtitle
    }
}
