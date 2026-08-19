import AppKit
import SwiftUI

struct MainWindow: View {
    @Bindable var state: AppState

    var body: some View {
        @Bindable var workspace = state.activeWorkspace

        NavigationSplitView(columnVisibility: $state.sidebarVisibility) {
            ProjectsSidebar(state: state)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            VStack(spacing: 0) {
                // With no tabs there is nothing to strip — showing an empty
                // bar with a lone "+" floating in it looks like a glitch.
                if !workspace.tabs.isEmpty {
                    TabStripView(state: state, workspace: workspace)
                }
                detail(for: workspace)
            }
            // Switching projects replaces the whole tab set, so the detail
            // side is rebuilt rather than diffed against another project's.
            .id(workspace.id)
        }
        .inspector(isPresented: $workspace.inspectorPresented) {
            InspectorView(state: state, workspace: workspace)
        }
        .navigationTitle(state.windowTitle)
        .navigationSubtitle(state.windowSubtitle)
        .toolbarRole(.editor)
        .toolbar {
            NativeTerminalToolbar(state: state, workspace: workspace)
        }
        .background(TitleSynchronizer(title: state.windowTitle, subtitle: state.windowSubtitle))
        .tint(Brand.primary)
        .frame(minWidth: 820, minHeight: 500)
    }

    @ViewBuilder
    private func detail(for workspace: Workspace) -> some View {
        if !workspace.tabs.isEmpty {
            // Every tab stays built and only the active one is shown. Tearing
            // the inactive ones down would make each switch re-parent a
            // SwiftTerm view, which is what made switching feel laggy.
            ZStack {
                ForEach(workspace.tabs) { tab in
                    WorkspaceView(tab: tab, state: state)
                        .opacity(tab.id == workspace.activeTabID ? 1 : 0)
                        .allowsHitTesting(tab.id == workspace.activeTabID)
                }
            }
        } else {
            ContentUnavailableView {
                Label("No Sessions", systemImage: "terminal")
            } description: {
                Text("This project has no open tabs.")
            } actions: {
                Button("New Tab") { state.newTab() }
                    .keyboardShortcut("t", modifiers: .command)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// `navigationTitle` alone does not reach a window this app created itself,
/// so the resolved strings are pushed onto the `NSWindow` as well.
private struct TitleSynchronizer: NSViewRepresentable {
    let title: String
    let subtitle: String

    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ nsView: NSView, context: Context) {
        let title = self.title
        let subtitle = self.subtitle
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.title = title
            window.subtitle = subtitle
        }
    }
}
