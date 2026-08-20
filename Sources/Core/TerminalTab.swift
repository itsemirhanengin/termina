import Foundation
import Observation

/// One tab in a workspace's tab strip: the folder it is rooted in and a split
/// tree of live shells. The project it belongs to is the workspace's business,
/// not the tab's — a tab only needs to know where its shells run.
@MainActor
@Observable
final class TerminalTab: Identifiable {
    let id = UUID()
    let folderURL: URL
    var root: PaneNode
    var focusedSessionID: UUID?
    /// User-chosen tab name. Wins over the shell title; clearing it hands the
    /// title back to the shell.
    var customTitle: String?

    init(folderURL: URL, root: PaneNode) {
        self.folderURL = folderURL
        self.root = root
        self.focusedSessionID = root.sessions.first?.id
    }

    var sessions: [TerminalSession] { root.sessions }

    var focusedSession: TerminalSession? {
        sessions.first { $0.id == focusedSessionID } ?? sessions.first
    }

    /// Shell-reported title of the focused pane, if the shell set one, with
    /// the spinner frame a working CLI prefixes it with peeled off.
    var shellTitle: ShellTitle? {
        let raw = focusedSession?.title ?? ""
        guard !raw.isEmpty else { return nil }
        let parsed = ShellTitle(raw)
        return parsed.text.isEmpty ? nil : parsed
    }

    var defaultTitle: String { folderURL.lastPathComponent }

    /// What the tab strip draws.
    var title: String { customTitle ?? shellTitle?.text ?? defaultTitle }

    /// True while the focused shell is spinning. The tab strip draws a native
    /// progress indicator for it — a renamed tab still shows the spinner,
    /// since the work is going on either way.
    var isBusy: Bool { shellTitle?.isBusy ?? false }

    /// Whitespace-only input clears the override so the tab follows the shell
    /// again, which is how the rename field's empty state is meant to read.
    func rename(to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        customTitle = trimmed.isEmpty ? nil : trimmed
    }
}
