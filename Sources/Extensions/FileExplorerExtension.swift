import AppKit
import SwiftUI

struct FileExplorerExtension: AppExtension {
    static let id = "co.bugece.termina.file-explorer"
    static let name = "File Explorer"

    func activate(_ context: ExtensionContext) {
        context.registerPanel(
            id: "file-explorer",
            title: "File Explorer",
            systemImage: "folder"
        ) { host in
            AnyView(FileExplorerPanel(host: host))
        }

        context.registerToolbarAction(
            id: "file-explorer.show",
            title: "File Explorer",
            systemImage: "folder"
        ) { host in
            host.showPanel(id: "file-explorer")
        }
    }
}

private struct FileExplorerPanel: View {
    let host: ExtensionHost
    @State private var refreshToken = UUID()

    var body: some View {
        if let project = host.activeProject {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Label(project.name, systemImage: "folder.fill")
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Button {
                        refreshToken = UUID()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh File Explorer")
                }
                .padding(.horizontal, 10)
                .frame(height: 36)

                Divider()

                NativeFileOutlineView(
                    rootURL: project.folderURL,
                    refreshToken: refreshToken
                )
            }
        } else {
            ContentUnavailableView(
                "No Project",
                systemImage: "folder.badge.questionmark",
                description: Text("Open a project to browse its files.")
            )
        }
    }
}

/// AppKit's outline view supplies the native disclosure, selection, keyboard,
/// accessibility, scrolling, and drag-era macOS interaction behavior.
private struct NativeFileOutlineView: NSViewRepresentable {
    let rootURL: URL
    let refreshToken: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(rootURL: rootURL, refreshToken: refreshToken)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let outlineView = NSOutlineView()
        let column = NSTableColumn(identifier: .fileNameColumn)
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator
        outlineView.backgroundColor = .clear
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.selectionHighlightStyle = .sourceList
        outlineView.indentationPerLevel = 14
        outlineView.intercellSpacing = NSSize(width: 0, height: 1)
        outlineView.rowHeight = 21
        outlineView.target = context.coordinator
        outlineView.doubleAction = #selector(Coordinator.openSelectedItem(_:))
        outlineView.menu = context.coordinator.makeContextMenu()

        let scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        context.coordinator.outlineView = outlineView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(rootURL: rootURL, refreshToken: refreshToken)
    }

    @MainActor
    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate {
        weak var outlineView: NSOutlineView?

        private var root: FileNode
        private var refreshToken: UUID

        init(rootURL: URL, refreshToken: UUID) {
            root = FileNode(url: rootURL)
            self.refreshToken = refreshToken
        }

        func update(rootURL: URL, refreshToken: UUID) {
            guard root.url != rootURL || self.refreshToken != refreshToken else { return }
            root = FileNode(url: rootURL)
            self.refreshToken = refreshToken
            outlineView?.reloadData()
        }

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            node(for: item).children.count
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            node(for: item).children[index]
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            (item as? FileNode)?.isExpandable ?? false
        }

        func outlineView(
            _ outlineView: NSOutlineView,
            viewFor tableColumn: NSTableColumn?,
            item: Any
        ) -> NSView? {
            guard let node = item as? FileNode else { return nil }

            let cell: NSTableCellView
            if let reused = outlineView.makeView(withIdentifier: .fileCell, owner: self)
                as? NSTableCellView {
                cell = reused
            } else {
                cell = makeFileCell()
            }

            cell.textField?.stringValue = node.name
            cell.textField?.toolTip = node.url.path

            let icon = NSWorkspace.shared.icon(forFile: node.url.path)
            icon.size = NSSize(width: 16, height: 16)
            cell.imageView?.image = icon
            cell.imageView?.toolTip = node.isExpandable ? "Folder" : node.name
            return cell
        }

        func outlineView(
            _ outlineView: NSOutlineView,
            shouldShowOutlineCellForItem item: Any
        ) -> Bool {
            (item as? FileNode)?.isExpandable ?? false
        }

        @objc func openSelectedItem(_ sender: Any?) {
            guard let outlineView, let node = node(at: outlineView.clickedRow) else { return }
            if node.isExpandable {
                if outlineView.isItemExpanded(node) {
                    outlineView.collapseItem(node, collapseChildren: false)
                } else {
                    outlineView.expandItem(node, expandChildren: false)
                }
            } else {
                NSWorkspace.shared.open(node.url)
            }
        }

        func makeContextMenu() -> NSMenu {
            let menu = NSMenu(title: "File")
            menu.delegate = self
            return menu
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            guard contextMenuNode != nil else { return }

            menu.addItem(withTitle: "Open", action: #selector(openContextItem(_:)), keyEquivalent: "")
            menu.addItem(
                withTitle: "Reveal in Finder",
                action: #selector(revealContextItem(_:)),
                keyEquivalent: ""
            )
            menu.addItem(.separator())
            menu.addItem(
                withTitle: "Copy Path",
                action: #selector(copyContextItemPath(_:)),
                keyEquivalent: ""
            )

            for item in menu.items where !item.isSeparatorItem {
                item.target = self
            }
        }

        @objc private func openContextItem(_ sender: Any?) {
            guard let node = contextMenuNode, let outlineView else { return }
            if node.isExpandable {
                outlineView.expandItem(node, expandChildren: false)
            } else {
                NSWorkspace.shared.open(node.url)
            }
        }

        @objc private func revealContextItem(_ sender: Any?) {
            guard let node = contextMenuNode else { return }
            NSWorkspace.shared.activateFileViewerSelecting([node.url])
        }

        @objc private func copyContextItemPath(_ sender: Any?) {
            guard let node = contextMenuNode else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(node.url.path, forType: .string)
        }

        private var contextMenuNode: FileNode? {
            guard let outlineView else { return nil }
            let row = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
            return node(at: row)
        }

        private func node(for item: Any?) -> FileNode {
            item as? FileNode ?? root
        }

        private func node(at row: Int) -> FileNode? {
            guard let outlineView, row >= 0 else { return nil }
            return outlineView.item(atRow: row) as? FileNode
        }

        private func makeFileCell() -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = .fileCell

            let imageView = NSImageView()
            imageView.imageScaling = .scaleProportionallyDown
            imageView.translatesAutoresizingMaskIntoConstraints = false

            let textField = NSTextField(labelWithString: "")
            textField.font = .systemFont(ofSize: NSFont.systemFontSize)
            textField.lineBreakMode = .byTruncatingMiddle
            textField.translatesAutoresizingMaskIntoConstraints = false

            cell.imageView = imageView
            cell.textField = textField
            cell.addSubview(imageView)
            cell.addSubview(textField)

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }
    }
}

@MainActor
private final class FileNode: NSObject {
    let url: URL
    let name: String
    let isExpandable: Bool

    private var cachedChildren: [FileNode]?

    init(url: URL) {
        self.url = url
        name = url.lastPathComponent

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        isExpandable = values?.isDirectory == true && values?.isPackage != true
    }

    var children: [FileNode] {
        if let cachedChildren { return cachedChildren }
        guard isExpandable else {
            cachedChildren = []
            return []
        }

        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isHiddenKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        let nodes = urls.map(FileNode.init).sorted { lhs, rhs in
            if lhs.isExpandable != rhs.isExpandable {
                return lhs.isExpandable && !rhs.isExpandable
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        cachedChildren = nodes
        return nodes
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let fileNameColumn = NSUserInterfaceItemIdentifier("FileNameColumn")
    static let fileCell = NSUserInterfaceItemIdentifier("FileCell")
}
