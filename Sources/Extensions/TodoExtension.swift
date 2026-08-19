import SwiftUI

/// Keeps a project's task list in `TODO.md` at its root.
///
/// The file lives in the repository on purpose: an agent running in one of the
/// project's terminals can read it, tick things off, and add work — so the
/// panel and the agent are looking at the same list rather than two copies.
struct TodoExtension: AppExtension {
    static let id = "com.itsemirhanengin.termina.todo"
    static let name = "TODO"

    func activate(_ context: ExtensionContext) {
        context.registerPanel(
            id: "todo",
            title: "TODO",
            systemImage: "checklist"
        ) { host in
            AnyView(TodoPanel(host: host))
        }

        context.registerToolbarAction(
            id: "todo.show",
            title: "TODO",
            systemImage: "checklist"
        ) { host in
            host.showPanel(id: "todo")
        }
    }
}

private struct TodoPanel: View {
    let host: ExtensionHost

    var body: some View {
        if let project = host.activeProject {
            TodoPanelView(
                store: TodoStoreRegistry.store(for: project.folderURL),
                projectName: project.name
            )
            // Switching projects switches lists; local edit state must not
            // carry over from the previous one.
            .id(project.id)
        } else {
            ContentUnavailableView(
                "No Project",
                systemImage: "checklist",
                description: Text("Open a project to keep its TODO list.")
            )
        }
    }
}
