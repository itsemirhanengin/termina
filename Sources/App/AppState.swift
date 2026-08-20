import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    // MARK: Projects & workspaces

    private(set) var projects: [Project] = []
    /// `nil` means the ad-hoc workspace rooted at the home folder, which is
    /// what the app shows before any project has been added.
    private(set) var activeProjectID: Project.ID?
    /// One workspace per project, created the first time that project is
    /// opened and kept for the rest of the session — that is what makes its
    /// tabs and inspector still be there when you come back to it.
    private var workspaces: [Workspace] = []

    var sidebarVisibility: NavigationSplitViewVisibility = .all

    // MARK: Extensions

    let extensions = ExtensionManager()
    @ObservationIgnored private(set) var host: ExtensionHost!

    // MARK: Appearance

    var activeThemeID: String {
        didSet {
            UserDefaults.standard.set(activeThemeID, forKey: "activeThemeID")
            applyAppearanceToAllSessions()
        }
    }

    var fontSize: Double {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: "fontSize")
            applyAppearanceToAllSessions()
        }
    }

    /// Family name, or `TerminalFont.systemFamily` for the system monospace.
    var fontFamily: String {
        didSet {
            UserDefaults.standard.set(fontFamily, forKey: "fontFamily")
            applyAppearanceToAllSessions()
        }
    }

    var terminalFont: NSFont {
        TerminalFont.resolve(family: fontFamily, size: fontSize)
    }

    @ObservationIgnored private let store = ProjectStore()

    private init() {
        activeThemeID = UserDefaults.standard.string(forKey: "activeThemeID") ?? "termina-dark"
        let storedSize = UserDefaults.standard.double(forKey: "fontSize")
        fontSize = storedSize > 0 ? storedSize : 13
        fontFamily = UserDefaults.standard.string(forKey: "fontFamily")
            ?? TerminalFont.defaultFamily()

        host = ExtensionHost(state: self)
        extensions.activateAll(host: host)

        let snapshot = store.load()
        projects = snapshot.projects.filter {
            FileManager.default.fileExists(atPath: $0.folderPath)
        }
        activeProjectID = projects.first { $0.id == snapshot.selectedProjectID }?.id
            ?? projects.first?.id

        installFocusMonitor()
        ShiftReturnKeyMonitor.install()
    }

    // MARK: Derived state

    var activeProject: Project? {
        projects.first { $0.id == activeProjectID }
    }

    /// Creates the workspace on first use so a project costs nothing until it
    /// is opened.
    var activeWorkspace: Workspace {
        workspace(for: activeProjectID)
    }

    var activeTab: TerminalTab? { activeWorkspace.activeTab }

    var focusedSession: TerminalSession? { activeWorkspace.focusedSession }

    var activeTheme: TerminalTheme {
        extensions.themes.first { $0.id == activeThemeID }
            ?? extensions.themes.first
            ?? TerminalTheme(
                id: "fallback", name: "Fallback", isDark: true,
                background: "#1E1E1E", foreground: "#DDDDDD",
                cursor: "#FFFFFF", selection: "#3E4451",
                ansi: [
                    "#000000", "#CC0000", "#4E9A06", "#C4A000",
                    "#3465A4", "#75507B", "#06989A", "#D3D7CF",
                    "#555753", "#EF2929", "#8AE234", "#FCE94F",
                    "#729FCF", "#AD7FA8", "#34E2E2", "#EEEEEC",
                ]
            )
    }

    var windowTitle: String { activeProject?.name ?? "Termina" }

    var windowSubtitle: String {
        guard let tab = activeTab else { return "" }
        var parts = [tab.title]
        if tab.sessions.count > 1 { parts.append("\(tab.sessions.count) panes") }
        return parts.joined(separator: " · ")
    }

    // MARK: Workspaces

    private func workspace(for projectID: Project.ID?) -> Workspace {
        if let existing = workspaces.first(where: { $0.projectID == projectID }) {
            return existing
        }
        let folder = projects.first { $0.id == projectID }?.folderURL
            ?? FileManager.default.homeDirectoryForCurrentUser
        let workspace = Workspace(projectID: projectID, folderURL: folder)
        workspace.selectedPanelID = extensions.panels.first?.id
        workspaces.append(workspace)
        // A workspace is never shown empty on first open.
        addTab(to: workspace)
        return workspace
    }

    func selectProject(_ projectID: Project.ID?) {
        guard projectID != activeProjectID else { return }
        activeProjectID = projectID
        _ = activeWorkspace
        persist()
        focusActiveSession()
    }

    // MARK: Project management

    func addProject(folderURL: URL) {
        if let existing = projects.first(where: { $0.folderPath == folderURL.path }) {
            selectProject(existing.id)
            return
        }

        let project = Project(folderURL: folderURL)
        projects.append(project)
        activeProjectID = project.id
        _ = activeWorkspace
        persist()
        focusActiveSession()
    }

    /// Applies an edit from the project sheet.
    func updateProject(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project
        persist()
    }

    func removeProject(_ project: Project) {
        // Take the workspace down with the project: its shells have no home left.
        if let workspace = workspaces.first(where: { $0.projectID == project.id }) {
            for tab in workspace.tabs {
                for session in tab.sessions { session.terminate() }
            }
            workspaces.removeAll { $0.projectID == project.id }
        }

        ProjectIconStore.discardStoredImage(for: project.icon)
        projects.removeAll { $0.id == project.id }

        if activeProjectID == project.id {
            activeProjectID = projects.first?.id
            _ = activeWorkspace
        }
        persist()
    }

    private func persist() {
        store.save(.init(projects: projects, selectedProjectID: activeProjectID))
    }

    // MARK: Tabs

    func newTab() {
        let workspace = activeWorkspace
        addTab(to: workspace)
        focusActiveSession()
    }

    @discardableResult
    private func addTab(to workspace: Workspace) -> TerminalTab {
        let session = makeSession(folder: workspace.folderURL)
        let tab = TerminalTab(folderURL: workspace.folderURL, root: .leaf(session))
        workspace.tabs.append(tab)
        workspace.activeTabID = tab.id
        return tab
    }

    func selectTab(_ tabID: TerminalTab.ID) {
        guard activeWorkspace.activeTabID != tabID else { return }
        activeWorkspace.activeTabID = tabID
        focusActiveSession()
    }

    func selectTab(at index: Int) {
        let workspace = activeWorkspace
        guard workspace.tabs.indices.contains(index) else { return }
        selectTab(workspace.tabs[index].id)
    }

    func moveTab(fromID: TerminalTab.ID, toIndex: Int) {
        let workspace = activeWorkspace
        guard let from = workspace.index(of: fromID) else { return }
        let destination = max(0, min(toIndex, workspace.tabs.count - 1))
        guard from != destination else { return }
        let tab = workspace.tabs.remove(at: from)
        workspace.tabs.insert(tab, at: destination)
    }

    /// Closing a tab kills its shells; the tab itself goes away as the last
    /// session reports back, so the two paths stay in one place.
    func closeTab(_ tabID: TerminalTab.ID) {
        guard let tab = activeWorkspace.tabs.first(where: { $0.id == tabID }) else { return }
        for session in tab.sessions { session.terminate() }
    }

    func closeActiveTab() {
        guard let tab = activeWorkspace.activeTab else { return }
        closeTab(tab.id)
    }

    func closeOtherTabs(than tabID: TerminalTab.ID) {
        for tab in activeWorkspace.tabs where tab.id != tabID {
            closeTab(tab.id)
        }
    }

    private func removeTab(_ tab: TerminalTab, from workspace: Workspace) {
        guard let index = workspace.index(of: tab.id) else { return }
        workspace.tabs.remove(at: index)
        if workspace.activeTabID == tab.id {
            // Land on the neighbour that slid into its place.
            let next = min(index, workspace.tabs.count - 1)
            workspace.activeTabID = next >= 0 ? workspace.tabs[next].id : nil
        }
        focusActiveSession()
    }

    // MARK: Panes

    func splitFocused(_ axis: SplitAxis) {
        guard let tab = activeTab, let focused = tab.focusedSession else { return }
        let session = makeSession(folder: tab.folderURL)
        tab.root = tab.root.splitting(sessionID: focused.id, axis: axis, newLeaf: session)
        tab.focusedSessionID = session.id
        focusActiveSession()
    }

    func closeFocusedPane() {
        focusedSession?.terminate()
    }

    func focusAdjacentPane(_ offset: Int) {
        guard let tab = activeTab, tab.sessions.count > 1,
              let focused = tab.focusedSession,
              let index = tab.sessions.firstIndex(where: { $0.id == focused.id })
        else { return }

        let count = tab.sessions.count
        let next = tab.sessions[(index + offset + count) % count]
        tab.focusedSessionID = next.id
        next.focus()
    }

    func focusActiveSession() {
        guard let session = focusedSession else { return }
        DispatchQueue.main.async { session.focus() }
    }

    // MARK: Sessions

    private func makeSession(folder: URL) -> TerminalSession {
        let session = TerminalSession(
            folderURL: folder,
            theme: activeTheme,
            font: terminalFont
        )
        session.onTerminated = { [weak self] session in
            self?.removeSessionFromTree(session)
        }
        return session
    }

    /// A shell exited — by ⌘W, by `exit`, or because its tab was closed.
    /// Sessions can belong to any workspace, not just the visible one.
    private func removeSessionFromTree(_ session: TerminalSession) {
        guard let workspace = workspaces.first(where: { workspace in
            workspace.tabs.contains { $0.root.contains(sessionID: session.id) }
        }),
        let tab = workspace.tabs.first(where: { $0.root.contains(sessionID: session.id) })
        else { return }

        let closedIndex = tab.sessions.firstIndex { $0.id == session.id } ?? 0

        guard let newRoot = tab.root.removing(sessionID: session.id) else {
            removeTab(tab, from: workspace)
            return
        }

        tab.root = newRoot
        if tab.focusedSessionID == session.id {
            let remaining = newRoot.sessions
            tab.focusedSessionID = remaining[min(closedIndex, remaining.count - 1)].id
        }
        focusActiveSession()
    }

    // MARK: Inspector & extensions

    func toggleSidebar() {
        sidebarVisibility = sidebarVisibility == .detailOnly ? .all : .detailOnly
    }

    func toggleInspector() {
        activeWorkspace.inspectorPresented.toggle()
    }

    func showPanel(id: String) {
        activeWorkspace.selectedPanelID = id
        activeWorkspace.inspectorPresented = true
    }

    private func applyAppearanceToAllSessions() {
        let theme = activeTheme
        let font = terminalFont
        for workspace in workspaces {
            for tab in workspace.tabs {
                for session in tab.sessions {
                    theme.apply(to: session.terminalView)
                    session.terminalView.font = font
                }
            }
        }
    }

    // MARK: Focus tracking

    private func installFocusMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.noteMouseDown(event)
            return event
        }
    }

    private func noteMouseDown(_ event: NSEvent) {
        guard let window = event.window, let tab = activeTab else { return }
        for session in tab.sessions {
            let view = session.terminalView
            guard view.window === window else { continue }
            let point = view.convert(event.locationInWindow, from: nil)
            if view.bounds.contains(point) {
                tab.focusedSessionID = session.id
                return
            }
        }
    }
}
