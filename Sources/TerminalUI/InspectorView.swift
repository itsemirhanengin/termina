import SwiftUI

/// The right-hand inspector hosts the panel chosen from the window toolbar.
/// Modules remain toolbar actions instead of becoming a second row of tabs.
struct InspectorView: View {
    @Bindable var state: AppState
    @Bindable var tab: TerminalTab

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
        return panels.first { $0.id == tab.selectedPanelID } ?? panels.first
    }
}
