import SwiftUI

struct WorkspaceView: View {
    var tab: TerminalTab
    var state: AppState

    var body: some View {
        PaneTreeView(node: tab.root)
            .id(tab.root.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color(nsColor: NSColor(hex: state.activeTheme.background)),
                ignoresSafeAreaEdges: []
            )
            .onAppear { state.focusActiveSession() }
    }
}
