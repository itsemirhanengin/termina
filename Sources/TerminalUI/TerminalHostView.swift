import AppKit
import SwiftUI

/// Bridges a session's long-lived SwiftTerm NSView into SwiftUI.
/// The terminal view is owned by the session, so scrollback and the
/// running process survive detach/re-attach when tabs switch or panes split.
///
/// Attaching is deferred to the next runloop turn: SwiftUI calls
/// make/updateNSView during layout, and moving an NSView between
/// superviews mid-layout throws a reentrant-layout exception.
struct TerminalHostView: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        scheduleAttach(to: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        if session.terminalView.superview !== container {
            scheduleAttach(to: container)
        }
    }

    private func scheduleAttach(to container: NSView) {
        let session = self.session
        DispatchQueue.main.async {
            let terminal = session.terminalView
            guard terminal.superview !== container else { return }
            terminal.removeFromSuperview()
            terminal.frame = container.bounds
            terminal.autoresizingMask = [.width, .height]
            container.addSubview(terminal)
            if container.window?.firstResponder === container.window {
                session.focus()
            }
        }
    }
}
