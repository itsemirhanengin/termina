import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The workspace's tab strip.
///
/// Ours rather than AppKit's window-tab bar because the tab set has to belong
/// to the selected project, which a real `NSWindow` tab group cannot do.
struct TabStripView: View {
    let state: AppState
    var workspace: Workspace

    private static let height: CGFloat = 38
    private static let verticalInset: CGFloat = 5

    @State private var hoveredTabID: TerminalTab.ID?
    @State private var renamingTabID: TerminalTab.ID?
    @State private var draggingTabID: TerminalTab.ID?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(workspace.tabs.enumerated()), id: \.element.id) { index, tab in
                TabItemView(
                    tab: tab,
                    isSelected: tab.id == workspace.activeTabID,
                    isHovered: tab.id == hoveredTabID,
                    isRenaming: renamingTabID == tab.id,
                    verticalInset: Self.verticalInset,
                    onSelect: { state.selectTab(tab.id) },
                    onClose: { state.closeTab(tab.id) },
                    onBeginRename: { renamingTabID = tab.id },
                    onEndRename: { newTitle in
                        if let newTitle { tab.rename(to: newTitle) }
                        renamingTabID = nil
                    },
                    onCloseOthers: { state.closeOtherTabs(than: tab.id) }
                )
                .frame(maxWidth: .infinity)
                .onHover { hovering in
                    if hovering { hoveredTabID = tab.id }
                    else if hoveredTabID == tab.id { hoveredTabID = nil }
                }
                .onDrag {
                    draggingTabID = tab.id
                    return NSItemProvider(object: tab.id.uuidString as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: TabReorderDropDelegate(
                        targetIndex: index,
                        draggingTabID: $draggingTabID,
                        move: { state.moveTab(fromID: $0, toIndex: $1) }
                    )
                )
                .transition(.opacity)
            }

            Button {
                state.newTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 30, height: Self.height - Self.verticalInset * 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New Tab (⌘T)")
        }
        // Widths are shared equally, so animating the set makes the existing
        // tabs slide apart as a new one lands between them.
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: workspace.tabs.map(\.id))
        .frame(height: Self.height)
        .padding(.horizontal, 6)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct TabItemView: View {
    let tab: TerminalTab
    let isSelected: Bool
    let isHovered: Bool
    let isRenaming: Bool
    let verticalInset: CGFloat
    let onSelect: () -> Void
    let onClose: () -> Void
    let onBeginRename: () -> Void
    /// `nil` title means the edit was abandoned.
    let onEndRename: (String?) -> Void
    let onCloseOthers: () -> Void

    @State private var draftTitle = ""
    /// Focus arrives a beat after the field appears, so a plain "lost focus"
    /// check would end the edit before it began.
    @State private var renameFieldEverFocused = false
    @FocusState private var renameFieldFocused: Bool

    var body: some View {
        // A plain Button selects on mouse-up with no delay. Pairing a single
        // and a double `onTapGesture` instead would make every click wait out
        // the double-click interval before anything happened.
        Button(action: onSelect) {
            label
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded { beginRename() })
        .contextMenu {
            Button("Rename Tab…") { beginRename() }
            Divider()
            Button("Close Tab") { onClose() }
            Button("Close Other Tabs") { onCloseOthers() }
        }
        .onChange(of: isRenaming) { _, renaming in
            if renaming {
                draftTitle = tab.customTitle ?? tab.title
                renameFieldEverFocused = false
                renameFieldFocused = true
            }
        }
        // Clicking away is the reflex for "never mind" — commit what is there
        // and leave edit mode rather than trapping the user in it.
        .onChange(of: renameFieldFocused) { _, focused in
            if focused {
                renameFieldEverFocused = true
            } else if renameFieldEverFocused && isRenaming {
                onEndRename(draftTitle)
            }
        }
    }

    private var label: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(background)
                .padding(.vertical, verticalInset)

            if isRenaming {
                TextField("", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .focused($renameFieldFocused)
                    .onSubmit { onEndRename(draftTitle) }
                    .onExitCommand { onEndRename(nil) }
                    .padding(.horizontal, 32)
            } else {
                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // Symmetric so the title stays optically centred whether
                    // or not the close button is showing.
                    .padding(.horizontal, 32)
            }

            if isHovered && !isRenaming {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 22, height: 22)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Close Tab (⌥⌘W)")
                    Spacer(minLength: 0)
                }
                .padding(.leading, verticalInset + 3)
            }
        }
        .contentShape(Rectangle())
    }

    private var background: Color {
        if isSelected { return Color.primary.opacity(0.16) }
        if isHovered { return Color.primary.opacity(0.07) }
        return .clear
    }

    private func beginRename() {
        onSelect()
        onBeginRename()
    }
}

/// Reorders while the drag passes over a neighbour, the way tab bars do —
/// there is no separate drop indicator to draw.
private struct TabReorderDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var draggingTabID: TerminalTab.ID?
    let move: (TerminalTab.ID, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingTabID else { return }
        move(draggingTabID, targetIndex)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingTabID = nil
        return true
    }
}
