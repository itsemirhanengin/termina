import SwiftUI

struct TerminaCommands: Commands {
    private var state: AppState { .shared }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tab") { state.newTab() }
                .keyboardShortcut("t", modifiers: .command)
            Button("Rename Tab…") { state.promptRenameActiveTab() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        // Keep macOS semantics: ⌘W closes the selected native window tab.
        CommandGroup(replacing: .saveItem) {
            Button("Close Tab") { state.closeCurrentTab() }
                .keyboardShortcut("w", modifiers: .command)
            Button("Close Pane") { state.closeFocusedPane() }
                .keyboardShortcut("w", modifiers: [.command, .option])
            Button("Close Window") {
                guard let keyWindow = NSApp.keyWindow else { return }
                for window in keyWindow.tabbedWindows ?? [keyWindow] {
                    window.performClose(nil)
                }
            }
                .keyboardShortcut("w", modifiers: [.command, .shift])
        }

        CommandMenu("Shell") {
            Button("Split Right") { state.splitFocused(.horizontal) }
                .keyboardShortcut("d", modifiers: .command)
            Button("Split Down") { state.splitFocused(.vertical) }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Divider()
            Button("Focus Next Pane") { state.focusAdjacentPane(1) }
                .keyboardShortcut("]", modifiers: [.command, .option])
            Button("Focus Previous Pane") { state.focusAdjacentPane(-1) }
                .keyboardShortcut("[", modifiers: [.command, .option])
        }

        CommandGroup(after: .toolbar) {
            Button("Toggle Sidebar") { state.toggleSidebar() }
                .keyboardShortcut("s", modifiers: [.command, .control])
            Button("Toggle Inspector") { state.toggleInspector() }
                .keyboardShortcut("i", modifiers: [.command, .option])
            Divider()
        }

        CommandGroup(before: .windowArrangement) {
            ForEach(1...9, id: \.self) { number in
                Button("Select Tab \(number)") { state.selectTab(at: number - 1) }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
            }
            Divider()
        }
    }
}
