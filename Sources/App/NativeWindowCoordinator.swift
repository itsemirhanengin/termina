import AppKit
import SwiftUI

/// Owns the bridge between terminal models and AppKit's real window tabs.
/// Every `TerminalTab` gets its own `NSWindow`, so tab reordering, detaching,
/// merging, keyboard navigation, and tab menus are provided by macOS.
@MainActor
final class NativeWindowCoordinator {
    static let shared = NativeWindowCoordinator()

    private let tabbingIdentifier = "co.bugece.termina.terminal"
    private var windows: [TerminalTab.ID: NSWindow] = [:]
    private var controllers: [TerminalTab.ID: NSWindowController] = [:]
    private var observers: [TerminalTab.ID: WindowObserver] = [:]

    private init() {
        NSWindow.allowsAutomaticWindowTabbing = true
    }

    func register(window: NSWindow, tab: TerminalTab, state: AppState) {
        configure(window, for: tab)

        if windows[tab.id] === window {
            update(window: window, for: tab)
            return
        }

        if let observer = observers[tab.id] {
            NotificationCenter.default.removeObserver(observer)
        }

        let observer = WindowObserver(tabID: tab.id, state: state)
        NotificationCenter.default.addObserver(
            observer,
            selector: #selector(WindowObserver.windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            observer,
            selector: #selector(WindowObserver.windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )

        windows[tab.id] = window
        observers[tab.id] = observer
        if window.isKeyWindow {
            state.windowDidBecomeKey(tabID: tab.id)
        }
    }

    func update(window: NSWindow, for tab: TerminalTab) {
        let title = tab.windowTitle
        window.title = title
        window.subtitle = tab.windowSubtitle
        window.tab.title = title
        window.tab.toolTip = tab.folderURL.path
    }

    func open(tab: TerminalTab, state: AppState, groupedWith sourceWindow: NSWindow?) {
        let rootView = MainWindow(state: state, tab: tab)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(sourceWindow?.contentView?.bounds.size ?? NSSize(width: 1180, height: 760))
        window.minSize = NSSize(width: 820, height: 500)
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        controllers[tab.id] = controller
        register(window: window, tab: tab, state: state)

        if let sourceWindow, sourceWindow !== window {
            sourceWindow.addTabbedWindow(window, ordered: .above)
        } else {
            controller.showWindow(nil)
        }
        window.makeKeyAndOrderFront(nil)
    }

    func activate(tabID: TerminalTab.ID) {
        windows[tabID]?.makeKeyAndOrderFront(nil)
    }

    func close(tabID: TerminalTab.ID) {
        windows[tabID]?.performClose(nil)
    }

    func selectTab(at index: Int) {
        guard index >= 0, let keyWindow = NSApp.keyWindow else { return }
        let tabbedWindows = keyWindow.tabbedWindows ?? [keyWindow]
        guard tabbedWindows.indices.contains(index) else { return }
        tabbedWindows[index].makeKeyAndOrderFront(nil)
    }

    fileprivate func unregister(tabID: TerminalTab.ID) {
        if let observer = observers.removeValue(forKey: tabID) {
            NotificationCenter.default.removeObserver(observer)
        }
        windows.removeValue(forKey: tabID)
        controllers.removeValue(forKey: tabID)
    }

    private func configure(_ window: NSWindow, for tab: TerminalTab) {
        window.tabbingMode = .preferred
        window.tabbingIdentifier = tabbingIdentifier
        window.toolbarStyle = .unified
        window.titleVisibility = .visible
        window.titlebarSeparatorStyle = .automatic
        window.isMovableByWindowBackground = false
        update(window: window, for: tab)
    }

}

@MainActor
private final class WindowObserver: NSObject {
    let tabID: TerminalTab.ID
    private weak var state: AppState?

    init(tabID: TerminalTab.ID, state: AppState) {
        self.tabID = tabID
        self.state = state
    }

    @objc func windowDidBecomeKey(_ notification: Notification) {
        state?.windowDidBecomeKey(tabID: tabID)
    }

    @objc func windowWillClose(_ notification: Notification) {
        state?.windowWillClose(tabID: tabID)
        NativeWindowCoordinator.shared.unregister(tabID: tabID)
    }
}
