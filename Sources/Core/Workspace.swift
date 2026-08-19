import Foundation
import Observation

/// Everything one project owns while the app runs: its tabs, which of them is
/// showing, and the state of the inspector.
///
/// Tabs hang off the project rather than off the window. That is what makes
/// picking a project in the sidebar swap the whole tab set, and what keeps the
/// inspector steady while you move between tabs of the same project.
@MainActor
@Observable
final class Workspace: Identifiable {
    let id = UUID()
    /// `nil` for the ad-hoc workspace used before any project is added.
    let projectID: Project.ID?
    let folderURL: URL

    var tabs: [TerminalTab] = []
    var activeTabID: TerminalTab.ID?

    var inspectorPresented = false
    var selectedPanelID: String?

    init(projectID: Project.ID?, folderURL: URL) {
        self.projectID = projectID
        self.folderURL = folderURL
    }

    var activeTab: TerminalTab? {
        tabs.first { $0.id == activeTabID } ?? tabs.first
    }

    var focusedSession: TerminalSession? { activeTab?.focusedSession }

    func index(of tabID: TerminalTab.ID) -> Int? {
        tabs.firstIndex { $0.id == tabID }
    }
}
