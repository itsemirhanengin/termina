import Foundation
import Observation

/// Collects every contribution registered by extensions at startup.
@MainActor
@Observable
final class ExtensionManager {
    var toolbarActions: [ToolbarAction] = []
    var panels: [ExtensionPanel] = []
    var themes: [TerminalTheme] = []

    func activateAll(host: ExtensionHost) {
        let context = ExtensionContext(manager: self, host: host)
        for extensionType in ExtensionRegistry.all {
            extensionType.init().activate(context)
        }
    }
}
