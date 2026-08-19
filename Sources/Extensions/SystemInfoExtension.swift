import SwiftUI

/// Sample extension proving the whole surface: a toolbar button that opens
/// an inspector panel showing project info, plus quick actions that type
/// into the focused terminal.
struct SystemInfoExtension: AppExtension {
    static let id = "co.bugece.termina.system-info"
    static let name = "Project Info"

    func activate(_ context: ExtensionContext) {
        context.registerPanel(
            id: "system-info",
            title: "Project Info",
            systemImage: "info.circle"
        ) { host in
            AnyView(SystemInfoPanel(host: host))
        }

        context.registerToolbarAction(
            id: "system-info.show",
            title: "Project Info",
            systemImage: "info.circle"
        ) { host in
            host.showPanel(id: "system-info")
        }
    }
}

private struct SystemInfoPanel: View {
    let host: ExtensionHost
    @Bindable var state: AppState = .shared

    var body: some View {
        Form {
            Section("Project") {
                LabeledContent("Name", value: host.activeProject?.name ?? "—")
                LabeledContent("Path", value: host.activeProject?.folderPath ?? "—")
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Section("Session") {
                LabeledContent(
                    "Shell",
                    value: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
                )
                LabeledContent(
                    "Panes in Tab",
                    value: "\(host.activeTab?.sessions.count ?? 0)"
                )
                LabeledContent("Theme", value: host.activeTheme.name)
            }

            Section("Quick Actions") {
                Button("git status") { host.sendText("git status\n") }
                Button("List Files") { host.sendText("ls -la\n") }
            }
        }
        .formStyle(.grouped)
    }
}
