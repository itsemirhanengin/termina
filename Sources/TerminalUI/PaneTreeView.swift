import SwiftUI

/// Recursively renders a tab's split tree using native split views.
struct PaneTreeView: View {
    let node: PaneNode

    var body: some View {
        switch node {
        case .leaf(let session):
            TerminalHostView(session: session)
                .id(session.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .split(_, let axis, let first, let second):
            SplitPaneView(axis: axis) {
                PaneTreeView(node: first)
            } second: {
                PaneTreeView(node: second)
            }
            .id(node.id)
        }
    }
}
