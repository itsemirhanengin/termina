import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    // MARK: Projects & native window tabs

    private(set) var projects: [Project] = []
    private(set) var tabs: [TerminalTab] = []
    private(set) var activeTabID: TerminalTab.ID?
    private(set) var initialTab: TerminalTab!
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

    @ObservationIgnored private let store = ProjectStore()

    private init() {
        activeThemeID = UserDefaults.standard.string(forKey: "activeThemeID") ?? "termina-dark"
        let storedSize = UserDefaults.standard.double(forKey: "fontSize")
        fontSize = storedSize > 0 ? storedSize : 13

        host = ExtensionHost(state: self)
        extensions.activateAll(host: host)

        let snapshot = store.load()
        projects = snapshot.projects.filter {
            FileManager.default.fileExists(atPath: $0.folderPath)
        }

        let project = projects.first { $0.id == snapshot.selectedProjectID } ?? projects.first
        let tab = makeTab(project: project)
        initialTab = tab
        tabs = [tab]
        activeTabID = tab.id
        installFocusMonitor()
    }

    // MARK: Derived state

    var activeTab: TerminalTab? {
        tabs.first { $0.id == activeTabID } ?? tabs.first
    }

    var activeProject: Project? { activeTab?.project }

    var focusedSession: TerminalSession? { activeTab?.focusedSession }

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

    // MARK: Project management

    func addProject(folderURL: URL) {
        if let existing = projects.first(where: { $0.folderPath == folderURL.path }) {
            openProject(existing.id)
            return
        }

        let project = Project(folderURL: folderURL)
        projects.append(project)
        persist(selectedProjectID: project.id)
        newTab(project: project)
    }

    func openProject(_ projectID: Project.ID) {
        guard let project = projects.first(where: { $0.id == projectID }) else { return }

        if let existing = tabs.first(where: { $0.project?.id == projectID }) {
            NativeWindowCoordinator.shared.activate(tabID: existing.id)
            return
        }

        newTab(project: project)
    }

    func removeProject(_ project: Project) {
        let projectTabs = tabs.filter { $0.project?.id == project.id }

        if projectTabs.count == tabs.count {
            let fallback = makeTab(project: nil)
            tabs.append(fallback)
            activeTabID = fallback.id
            NativeWindowCoordinator.shared.open(
                tab: fallback,
                state: self,
                groupedWith: NSApp.keyWindow
            )
        }

        projects.removeAll { $0.id == project.id }
        for tab in projectTabs {
            NativeWindowCoordinator.shared.close(tabID: tab.id)
        }
        persist(selectedProjectID: activeProject?.id)
    }

    private func persist(selectedProjectID: Project.ID?) {
        store.save(.init(projects: projects, selectedProjectID: selectedProjectID))
    }

    // MARK: Native tabs

    func newTab() {
        newTab(project: activeProject)
    }

    private func newTab(project: Project?) {
        let tab = makeTab(project: project)
        tabs.append(tab)
        activeTabID = tab.id
        NativeWindowCoordinator.shared.open(
            tab: tab,
            state: self,
            groupedWith: NSApp.keyWindow
        )
        persist(selectedProjectID: project?.id)
    }

    func closeCurrentTab() {
        guard let tab = activeTab else { return }
        NativeWindowCoordinator.shared.close(tabID: tab.id)
    }

    func selectTab(at index: Int) {
        NativeWindowCoordinator.shared.selectTab(at: index)
    }

    func windowDidBecomeKey(tabID: TerminalTab.ID) {
        guard tabs.contains(where: { $0.id == tabID }) else { return }
        activeTabID = tabID
        persist(selectedProjectID: activeProject?.id)
        focusActiveSession()
    }

    func windowWillClose(tabID: TerminalTab.ID) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        for session in tab.sessions { session.terminate() }
        tabs.removeAll { $0.id == tabID }
        if activeTabID == tabID {
            activeTabID = tabs.first?.id
        }
    }

    private func makeTab(project: Project?) -> TerminalTab {
        let folder = project?.folderURL ?? FileManager.default.homeDirectoryForCurrentUser
        let session = makeSession(folder: folder)
        let tab = TerminalTab(project: project, root: .leaf(session))
        tab.selectedPanelID = extensions.panels.first?.id
        return tab
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
            fontSize: fontSize
        )
        session.onTerminated = { [weak self] session in
            self?.removeSessionFromTree(session)
        }
        return session
    }

    private func removeSessionFromTree(_ session: TerminalSession) {
        guard let tab = tabs.first(where: { $0.root.contains(sessionID: session.id) }) else {
            return
        }

        if let newRoot = tab.root.removing(sessionID: session.id) {
            tab.root = newRoot
            if tab.focusedSessionID == session.id {
                tab.focusedSessionID = newRoot.sessions.first?.id
            }
            focusActiveSession()
        } else {
            NativeWindowCoordinator.shared.close(tabID: tab.id)
        }
    }

    // MARK: Inspector & extensions

    func toggleInspector() {
        activeTab?.inspectorPresented.toggle()
    }

    func showPanel(id: String) {
        activeTab?.selectedPanelID = id
        activeTab?.inspectorPresented = true
    }

    private func applyAppearanceToAllSessions() {
        let theme = activeTheme
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        for tab in tabs {
            for session in tab.sessions {
                theme.apply(to: session.terminalView)
                session.terminalView.font = font
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
