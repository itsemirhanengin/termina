import SwiftUI

/// Native toolbar content. Buttons remain plain toolbar items so macOS can
/// provide the platform material, hover feedback, and shared glass capsules.
struct NativeTerminalToolbar: ToolbarContent {
    let state: AppState
    let tab: TerminalTab

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            sessionActions
        }

        if #available(macOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .primaryAction)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            extensionActions
        }
    }

    @ViewBuilder
    private var sessionActions: some View {
        Button {
            state.newTab()
        } label: {
            Label("New Tab", systemImage: "plus.rectangle.on.rectangle")
        }
        .help("New Tab (⌘T)")

        Button {
            state.splitFocused(.horizontal)
        } label: {
            Label("Split Right", systemImage: "rectangle.split.2x1")
        }
        .help("Split Right (⌘D)")

        Button {
            state.splitFocused(.vertical)
        } label: {
            Label("Split Down", systemImage: "rectangle.split.1x2")
        }
        .help("Split Down (⇧⌘D)")
    }

    @ViewBuilder
    private var extensionActions: some View {
        ForEach(state.extensions.toolbarActions) { item in
            Button {
                item.action(state.host)
            } label: {
                Label(item.title, systemImage: item.systemImage)
            }
            .help(item.title)
        }

        Button {
            tab.inspectorPresented.toggle()
        } label: {
            Label("Toggle Inspector", systemImage: "sidebar.trailing")
                .symbolVariant(tab.inspectorPresented ? .fill : .none)
        }
        .help("Toggle Inspector (⌥⌘I)")
    }
}
