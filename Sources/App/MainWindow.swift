import AppKit
import SwiftUI

struct MainWindow: View {
    @Bindable var state: AppState
    @Bindable var tab: TerminalTab

    var body: some View {
        NavigationSplitView(columnVisibility: $state.sidebarVisibility) {
            ProjectsSidebar(state: state, tab: tab)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            WorkspaceView(tab: tab, state: state)
        }
        .inspector(isPresented: $tab.inspectorPresented) {
            InspectorView(state: state, tab: tab)
        }
        .navigationTitle(tab.windowTitle)
        .navigationSubtitle(tab.windowSubtitle)
        .toolbarRole(.editor)
        .toolbar {
            NativeTerminalToolbar(state: state, tab: tab)
        }
        .background(WindowConfigurator(state: state, tab: tab))
        .frame(minWidth: 820, minHeight: 500)
    }
}

/// Captures the SwiftUI-owned `NSWindow` and enrolls it in AppKit's native
/// tabbing system. Updates also keep shell-provided titles in sync.
private struct WindowConfigurator: NSViewRepresentable {
    let state: AppState
    let tab: TerminalTab

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            NativeWindowCoordinator.shared.register(window: window, tab: tab, state: state)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            NativeWindowCoordinator.shared.register(window: window, tab: tab, state: state)
        }
    }
}
