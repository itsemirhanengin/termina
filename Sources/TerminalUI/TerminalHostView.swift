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
    /// The active theme's background, painted behind the inset terminal so
    /// the gutter reads as part of the same surface.
    let surface: NSColor

    /// Breathing room between the glyphs and the pane edge. SwiftTerm draws
    /// text flush to its bounds, so the padding lives in the host container.
    private static let inset = NSSize(width: 14, height: 10)

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = surface.cgColor
        scheduleAttach(to: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        container.layer?.backgroundColor = surface.cgColor
        if session.terminalView.superview !== container {
            scheduleAttach(to: container)
        }
    }

    private func scheduleAttach(to container: NSView) {
        let session = self.session
        let inset = Self.inset
        DispatchQueue.main.async {
            let terminal = session.terminalView
            guard terminal.superview !== container else { return }
            terminal.removeFromSuperview()
            terminal.frame = container.bounds.insetBy(dx: inset.width, dy: inset.height)
            terminal.autoresizingMask = [.width, .height]
            container.addSubview(terminal)
            if container.window?.firstResponder === container.window {
                session.focus()
            }
        }
    }
}
