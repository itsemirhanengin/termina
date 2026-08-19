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
    /// User-chosen tab name. Wins over the shell title; clearing it hands the
    /// title back to the shell.
    var customTitle: String?

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
    var windowTitle: String { customTitle ?? shellTitle ?? name }

    /// Second line in the toolbar; empty when it would just repeat the title.
    var windowSubtitle: String {
        var parts: [String] = []
        if windowTitle != name { parts.append(name) }
        if sessions.count > 1 { parts.append("\(sessions.count) panes") }
        return parts.joined(separator: " · ")
    }

    /// Renames the tab. Whitespace-only input clears the override so the tab
    /// follows the shell again, which is also how the rename sheet's empty
    /// field is meant to read.
    func rename(to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        customTitle = trimmed.isEmpty ? nil : trimmed
        NativeWindowCoordinator.shared.refresh(tab: self)
    }
}
