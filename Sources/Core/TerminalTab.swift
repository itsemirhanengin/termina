import Foundation
import Observation

/// One native window tab: the folder it is rooted in, a split tree of live
/// shells, and the per-tab UI state. Because macOS window tabs are real
/// windows, everything a tab shows (sidebar selection, inspector panel)
/// belongs here rather than to the app.
@MainActor
@Observable
final class TerminalTab: Identifiable {
    let id = UUID()

    /// `nil` for an ad-hoc terminal (no projects added yet): rooted at home.
    var project: Project?
    var root: PaneNode
    var focusedSessionID: UUID?
    var selectedPanelID: String?
    var inspectorPresented = false

    init(project: Project?, root: PaneNode) {
        self.project = project
        self.root = root
        self.focusedSessionID = root.sessions.first?.id
    }

    var folderURL: URL {
        project?.folderURL ?? FileManager.default.homeDirectoryForCurrentUser
    }

    var name: String {
        project?.name ?? folderURL.lastPathComponent
    }

    var sessions: [TerminalSession] { root.sessions }

    var focusedSession: TerminalSession? {
        sessions.first { $0.id == focusedSessionID } ?? sessions.first
    }

    /// Shell-reported title of the focused pane, if the shell set one.
    var shellTitle: String? {
        let title = focusedSession?.title ?? ""
        return title.isEmpty ? nil : title
    }

    /// Label macOS puts on the native tab.
    var windowTitle: String { shellTitle ?? name }

    /// Second line in the toolbar; empty when it would just repeat the title.
    var windowSubtitle: String {
        var parts: [String] = []
        if shellTitle != nil { parts.append(name) }
        if sessions.count > 1 { parts.append("\(sessions.count) panes") }
        return parts.joined(separator: " · ")
    }
}
