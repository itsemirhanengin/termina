import SwiftUI

/// The right-hand inspector hosts the panel chosen from the window toolbar.
/// Its state belongs to the workspace, so moving between a project's tabs
/// leaves the panel exactly where it was.
struct InspectorView: View {
    let state: AppState
    var workspace: Workspace

    var body: some View {
        Group {
            if let panel = selectedPanel {
                panel.makeView(state.host)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ContentUnavailableView(
                    "No Panels",
                    systemImage: "sidebar.trailing",
                    description: Text("Extensions can add panels here.")
                )
            }
        }
        .inspectorColumnWidth(min: 240, ideal: 280, max: 420)
    }

    private var selectedPanel: ExtensionPanel? {
        let panels = state.extensions.panels
        return panels.first { $0.id == workspace.selectedPanelID } ?? panels.first
    }
}
