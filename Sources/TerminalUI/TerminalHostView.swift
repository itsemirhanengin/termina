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

    /// Positions the terminal with constraints rather than a frame computed
    /// from `container.bounds`. When a split collapses, the surviving pane's
    /// container is created empty — no window, zero bounds — and the attach
    /// lands before AppKit has sized it. Insetting a zero rect yields a
    /// negative frame, which autoresizing then scales from a zero-sized
    /// superview and parks the terminal at ~1e10 points, blanking the pane.
    /// Constraints simply wait for the real size.
    private func scheduleAttach(to container: NSView) {
        let session = self.session
        let inset = Self.inset
        DispatchQueue.main.async {
            let terminal = session.terminalView
            guard terminal.superview !== container else { return }

            terminal.removeFromSuperview()
            terminal.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(terminal)
            NSLayoutConstraint.activate([
                terminal.leadingAnchor.constraint(
                    equalTo: container.leadingAnchor, constant: inset.width),
                terminal.trailingAnchor.constraint(
                    equalTo: container.trailingAnchor, constant: -inset.width),
                terminal.topAnchor.constraint(
                    equalTo: container.topAnchor, constant: inset.height),
                terminal.bottomAnchor.constraint(
                    equalTo: container.bottomAnchor, constant: -inset.height),
            ])

            // The move happens while the view is out of the hierarchy, so any
            // redraw it asked for on the way was dropped.
            terminal.needsDisplay = true

            if container.window?.firstResponder === container.window {
                session.focus()
            }
        }
    }
}
