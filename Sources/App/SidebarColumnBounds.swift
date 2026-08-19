import AppKit
import SwiftUI

/// Bounds the sidebar column and remembers its width.
///
/// SwiftUI builds this window's `NavigationSplitView` out of a bare
/// `NSSplitView` — there is no `NSSplitViewController`, so `NSSplitViewItem`'s
/// `minimumThickness` / `maximumThickness` have nothing to attach to, and
/// `navigationSplitViewColumnWidth(min:ideal:max:)` is ignored (the column
/// sits at whatever the user last dragged it to, and can be dragged across the
/// whole window). Clamping the divider directly is the part of this that
/// AppKit will honour.
///
/// Placed *inside* the sidebar column so the first `NSSplitView` above it is
/// the sidebar/detail one rather than the outer inspector split.
struct SidebarColumnBounds: NSViewRepresentable {
    static let minimumWidth: CGFloat = 190
    static let maximumWidth: CGFloat = 360
    static let defaultWidth: CGFloat = 240

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        let coordinator = context.coordinator
        DispatchQueue.main.async { coordinator.attach(startingAt: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        DispatchQueue.main.async { coordinator.attach(startingAt: nsView) }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject {
        private static let widthKey = "sidebarWidth"

        private weak var splitView: NSSplitView?
        private var isAdjusting = false

        func attach(startingAt view: NSView) {
            guard splitView == nil else { return }
            guard let found = Self.enclosingSplitView(of: view) else { return }
            splitView = found

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(splitViewDidResize(_:)),
                name: NSSplitView.didResizeSubviewsNotification,
                object: found
            )
            restoreWidth(in: found)
        }

        func detach() {
            NotificationCenter.default.removeObserver(self)
            splitView = nil
        }

        /// The split view whose *leading* pane contains us. Walking up to the
        /// first `NSSplitView` is not enough: this window nests the sidebar
        /// split inside the inspector split, and grabbing the wrong one would
        /// clamp the terminal instead of the sidebar.
        private static func enclosingSplitView(of view: NSView) -> NSSplitView? {
            var child = view
            while let parent = child.superview {
                if let split = parent as? NSSplitView,
                   split.isVertical,
                   split.subviews.count >= 2,
                   split.subviews.first === child {
                    return split
                }
                child = parent
            }
            return nil
        }

        private func restoreWidth(in splitView: NSSplitView) {
            let stored = UserDefaults.standard.double(forKey: Self.widthKey)
            let width = stored > 0 ? CGFloat(stored) : SidebarColumnBounds.defaultWidth
            setWidth(clamp(width), in: splitView)
        }

        @objc private func splitViewDidResize(_ notification: Notification) {
            guard !isAdjusting, let splitView, let sidebar = splitView.subviews.first else { return }
            // A collapsed sidebar is a legitimate state (⌃⌘S), not a width to
            // clamp or remember.
            let width = sidebar.frame.width
            guard width > 1 else { return }

            let bounded = clamp(width)
            if abs(bounded - width) > 0.5 {
                setWidth(bounded, in: splitView)
            } else {
                UserDefaults.standard.set(Double(width), forKey: Self.widthKey)
            }
        }

        private func clamp(_ width: CGFloat) -> CGFloat {
            min(max(width, SidebarColumnBounds.minimumWidth), SidebarColumnBounds.maximumWidth)
        }

        /// `setPosition` re-enters the resize notification, hence the guard.
        private func setWidth(_ width: CGFloat, in splitView: NSSplitView) {
            isAdjusting = true
            splitView.setPosition(width, ofDividerAt: 0)
            isAdjusting = false
            UserDefaults.standard.set(Double(width), forKey: Self.widthKey)
        }
    }
}
