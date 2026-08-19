import SwiftUI

/// The extension entry point. Add your type to `ExtensionRegistry.all`
/// and register contributions inside `activate(_:)`.
@MainActor
protocol AppExtension {
    static var id: String { get }
    static var name: String { get }
    init()
    func activate(_ context: ExtensionContext)
}

/// A button contributed to the window toolbar.
struct ToolbarAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let action: @MainActor (ExtensionHost) -> Void
}

/// A panel contributed to the right-hand inspector.
struct ExtensionPanel: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let makeView: @MainActor (ExtensionHost) -> AnyView
}

/// Handed to each extension during activation; all contributions go through here.
@MainActor
final class ExtensionContext {
    private unowned let manager: ExtensionManager
    let host: ExtensionHost

    init(manager: ExtensionManager, host: ExtensionHost) {
        self.manager = manager
        self.host = host
    }

    func registerToolbarAction(
        id: String,
        title: String,
        systemImage: String,
        action: @escaping @MainActor (ExtensionHost) -> Void
    ) {
        manager.toolbarActions.append(
            ToolbarAction(id: id, title: title, systemImage: systemImage, action: action)
        )
    }

    func registerPanel(
        id: String,
        title: String,
        systemImage: String,
        content: @escaping @MainActor (ExtensionHost) -> AnyView
    ) {
        manager.panels.append(
            ExtensionPanel(id: id, title: title, systemImage: systemImage, makeView: content)
        )
    }

    func registerTheme(_ theme: TerminalTheme) {
        manager.themes.append(theme)
    }
}
