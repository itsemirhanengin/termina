# Termina

A native macOS terminal with project-based workspaces, built with SwiftUI + [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm).

- **Projects sidebar** — add folders and open them in native macOS window tabs.
- **Tabs & splits** — every `NSWindow` tab owns a binary split tree of terminal panes (real `NSSplitView` dividers).
- **Native UI** — AppKit window tabs, a unified SwiftUI toolbar, `NavigationSplitView`, and an Xcode-style `.inspector()` panel.
- **Extension architecture** — toolbar actions, inspector panels, and color themes are all pluggable; the built-in features use the same API.
- **Native file explorer** — browse the active project with an AppKit outline view, system file icons, keyboard navigation, and Finder actions.

## Building

Requires Xcode 16+ (macOS 15 target) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project Termina.xcodeproj -scheme Termina -skipPackagePluginValidation build
```

`-skipPackagePluginValidation` is needed for SwiftTerm's build-info plugin when building from the CLI. Opening `Termina.xcodeproj` in Xcode and hitting Run also works (Xcode will ask you to trust the plugin once).

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘T | New tab |
| ⌘W | Close native tab |
| ⌥⌘W | Close focused pane |
| ⇧⌘W | Close tabbed window |
| ⌘1–9 | Select tab |
| ⌘D / ⇧⌘D | Split right / split down |
| ⌥⌘] / ⌥⌘[ | Focus next / previous pane |
| ⌥⌘I | Toggle inspector |

## Writing an extension

Create a folder under `Sources/Extensions/`, implement `AppExtension`, and add one line to `ExtensionRegistry.all`:

```swift
struct MyExtension: AppExtension {
    static let id = "com.example.my-extension"
    static let name = "My Extension"

    func activate(_ context: ExtensionContext) {
        context.registerToolbarAction(id: "my.action", title: "Do Thing", systemImage: "bolt") { host in
            host.sendText("echo hello\n")       // type into the focused terminal
            host.showPanel(id: "my.panel")      // open an inspector panel
        }
        context.registerPanel(id: "my.panel", title: "My Panel", systemImage: "bolt") { host in
            AnyView(Text("Hello, \(host.activeProject?.name ?? "world")"))
        }
        context.registerTheme(TerminalTheme(/* ... */))
    }
}
```

`ExtensionHost` is the API surface: active project/tab/session, `sendText`, `showPanel`, `setTheme`, `newTab`, and the theme list.

## Architecture

```
Sources/
├── App/           @main, root AppState, main window, menu commands, settings
├── Core/          Project, TerminalTab, PaneNode (split tree), TerminalSession
├── TerminalUI/    SwiftTerm bridge, pane tree renderer, NSSplitView wrapper, toolbar, sidebar, inspector
├── ExtensionKit/  AppExtension protocol, ExtensionContext/Host/Manager/Registry, TerminalTheme
└── Extensions/    Built-in extensions (themes, project info panel)
```

Notes for contributors:

- Every `TerminalTab` is backed by a real `NSWindow`; AppKit supplies tab selection, reordering, detaching, merging, and tab menus.
- `TerminalSession` owns its `LocalProcessTerminalView`; SwiftUI only re-attaches the same NSView, so scrollback and the shell survive native tab switches.
- NSView re-parenting is always deferred to the next runloop turn (`TerminalHostView`) — doing it inside SwiftUI's layout pass throws a reentrant-layout exception.
- The app is intentionally **not sandboxed** (a terminal needs arbitrary shell/folder access), so it's distributed outside the App Store.
