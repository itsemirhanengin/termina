import AppKit
import SwiftUI

struct ProjectsSidebar: View {
    @Bindable var state: AppState
    let tab: TerminalTab

    @State private var editingProject: Project?

    var body: some View {
        List(selection: projectSelection) {
            Section("Projects") {
                ForEach(state.projects) { project in
                    row(for: project)
                        .tag(project.id)
                        .contextMenu {
                            Button("Edit Project…") { editingProject = project }
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([project.folderURL])
                            }
                            Divider()
                            Button("Remove from Sidebar", role: .destructive) {
                                state.removeProject(project)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                Button {
                    addProject()
                } label: {
                    Label("Add Project", systemImage: "plus")
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .background(SidebarColumnBounds())
        .sheet(item: $editingProject) { project in
            ProjectEditorView(project: project) { state.updateProject($0) }
        }
    }

    /// The description, when there is one, sits under the name the way
    /// Finder and Mail stack a secondary line — it must never push the row's
    /// height around when empty.
    @ViewBuilder
    private func row(for project: Project) -> some View {
        HStack(spacing: 6) {
            ProjectIconView(icon: project.icon, size: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .lineLimit(1)
                if !project.notes.isEmpty {
                    Text(project.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .help(project.notes.isEmpty ? project.folderPath : "\(project.notes)\n\(project.folderPath)")
    }

    private var projectSelection: Binding<Project.ID?> {
        Binding(
            get: { tab.project?.id },
            set: { projectID in
                guard let projectID, projectID != tab.project?.id else { return }
                state.openProject(projectID)
            }
        )
    }

    private func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Project"
        panel.message = "Choose a project folder"
        if panel.runModal() == .OK, let url = panel.url {
            state.addProject(folderURL: url)
        }
    }
}
