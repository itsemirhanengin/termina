import AppKit
import SwiftUI

/// A terminal window. The only reason it is a subclass is `newWindowForTab`:
/// the "+" at the end of the native tab bar sends that action down the
/// responder chain, and nothing else in the chain knows how to make a
/// `TerminalTab`. Without this the button is drawn but does nothing.
final class TerminaWindow: NSWindow {
    @objc override func newWindowForTab(_ sender: Any?) {
        AppState.shared.newTab()
    }
}

/// Owns the bridge between terminal models and AppKit's real window tabs.
/// Every `TerminalTab` gets its own `NSWindow`, so tab reordering, detaching,
/// merging, keyboard navigation, and tab menus are provided by macOS.
@MainActor
final class NativeWindowCoordinator {
    static let shared = NativeWindowCoordinator()

    private let tabbingIdentifier = "co.bugece.termina.terminal"
    private let frameAutosaveName = "co.bugece.termina.main"
    private var windows: [TerminalTab.ID: NSWindow] = [:]
    private var controllers: [TerminalTab.ID: NSWindowController] = [:]
    private var observers: [TerminalTab.ID: WindowObserver] = [:]

    private init() {
        NSWindow.allowsAutomaticWindowTabbing = true
        installTabBarRenameMonitor()
    }

    /// Double-click a native tab to rename it. AppKit gives `NSWindowTab`
    /// nothing but a `title` property — no rename UI, no context menu — so the
    /// gesture has to be recognised here. The click is swallowed so the window
    /// does not also zoom.
    private func installTabBarRenameMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { event in
            guard event.clickCount == 2,
                  let window = event.window as? TerminaWindow,
                  Self.isInTabBar(event.locationInWindow, of: window)
            else { return event }

            // The first click of the pair already selected the tab, so by the
            // next runloop turn the clicked tab is the active one.
            DispatchQueue.main.async { AppState.shared.promptRenameActiveTab() }
            return nil
        }
    }

    /// The tab bar is the strip between the content area and the title bar.
    /// `contentLayoutRect` gives us its lower edge; the upper edge is one tab
    /// bar's height above it — anything higher is the title bar, where a
    /// double-click still means zoom.
    private static func isInTabBar(_ point: NSPoint, of window: NSWindow) -> Bool {
        guard window.tabGroup?.isTabBarVisible == true,
              let contentView = window.contentView else { return false }

        let contentTop = window.contentLayoutRect.maxY
        let tabBarHeight: CGFloat = 28
        guard point.y > contentTop, point.y <= contentTop + tabBarHeight else { return false }

        guard let hit = contentView.superview?.hitTest(point) else { return false }
        return !hit.isDescendant(of: contentView)
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
        let window = TerminaWindow(contentViewController: hostingController)
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
            // Only the first window of a group restores a saved frame; tabs
            // inherit the group's frame from AppKit.
            window.setFrameAutosaveName(frameAutosaveName)
            if window.frame.origin == .zero { window.center() }
            controller.showWindow(nil)
        }
        window.makeKeyAndOrderFront(nil)
    }

    /// Re-reads the tab's title after a rename.
    func refresh(tab: TerminalTab) {
        guard let window = windows[tab.id] else { return }
        update(window: window, for: tab)
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
