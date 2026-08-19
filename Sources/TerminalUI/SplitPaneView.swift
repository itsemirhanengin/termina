import AppKit
import SwiftUI

/// A real NSSplitView hosting two SwiftUI children. Used instead of
/// SwiftUI's H/VSplitView for native divider behavior, a 50/50 initial
/// position, and to keep the terminal views out of SwiftUI's measuring
/// pass (which can feedback-loop with SwiftTerm's resize handling).
struct SplitPaneView<First: View, Second: View>: NSViewRepresentable {
    let axis: SplitAxis
    @ViewBuilder let first: () -> First
    @ViewBuilder let second: () -> Second

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = (axis == .horizontal)
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator

        let firstHost = NSHostingView(rootView: first())
        let secondHost = NSHostingView(rootView: second())
        context.coordinator.firstHost = firstHost
        context.coordinator.secondHost = secondHost
        splitView.addArrangedSubview(firstHost)
        splitView.addArrangedSubview(secondHost)

        DispatchQueue.main.async {
            let length = splitView.isVertical
                ? splitView.bounds.width : splitView.bounds.height
            guard length > 0 else { return }
            splitView.setPosition(length / 2, ofDividerAt: 0)
        }
        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        context.coordinator.firstHost?.rootView = first()
        context.coordinator.secondHost?.rootView = second()
    }

    final class Coordinator: NSObject, NSSplitViewDelegate {
        var firstHost: NSHostingView<First>?
        var secondHost: NSHostingView<Second>?

        private let minimumPaneLength: CGFloat = 100

        func splitView(
            _ splitView: NSSplitView,
            constrainMinCoordinate proposedMinimumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            max(proposedMinimumPosition, minimumPaneLength)
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainMaxCoordinate proposedMaximumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            let length = splitView.isVertical
                ? splitView.bounds.width : splitView.bounds.height
            return min(proposedMaximumPosition, length - minimumPaneLength)
        }

        func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
            // Keep both panes proportional when the window resizes.
            splitView.adjustSubviews()
        }
    }
}
