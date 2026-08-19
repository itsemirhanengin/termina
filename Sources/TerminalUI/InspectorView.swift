import SwiftUI

/// The right-hand inspector: hosts every panel registered by extensions,
/// with a segmented switcher when there is more than one.
struct InspectorView: View {
    @Bindable var state: AppState
    @Bindable var tab: TerminalTab

    var body: some View {
        let panels = state.extensions.panels
        VStack(spacing: 0) {
            if panels.count > 1 {
                Picker("Panel", selection: $tab.selectedPanelID) {
                    ForEach(panels) { panel in
                        Image(systemName: panel.systemImage)
                            .help(panel.title)
                            .tag(Optional(panel.id))
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                Divider()
            }

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
