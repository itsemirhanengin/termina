import AppKit
import SwiftUI

struct ProjectsSidebar: View {
    @Bindable var state: AppState
    let tab: TerminalTab

    var body: some View {
        List(selection: projectSelection) {
            Section("Projects") {
                ForEach(state.projects) { project in
                    Label(project.name, systemImage: "folder")
                        .tag(project.id)
                        .help(project.folderPath)
                        .contextMenu {
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
        .navigationSplitViewColumnWidth(min: 170, ideal: 220, max: 320)
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
