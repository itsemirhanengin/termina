import AppKit
import SwiftUI

/// The inspector panel over a project's `TODO.md`.
struct TodoPanelView: View {
    let store: TodoStore
    let projectName: String

    /// The task currently being typed into. Held here rather than in the row
    /// so only one is ever editable.
    @State private var editingID: TodoItem.ID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 8) {
            Label("TODO", systemImage: "checklist")
                .font(.headline)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                addTask()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("New Task")
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
    }

    @ViewBuilder
    private var content: some View {
        if store.document.items.isEmpty {
            ContentUnavailableView {
                Label("No Tasks", systemImage: "checklist.unchecked")
            } description: {
                Text("Tasks are kept in TODO.md at the project root.")
            } actions: {
                Button("New Task") { addTask() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(store.document.items) { item in
                        TodoRowView(
                            item: item,
                            isEditing: editingID == item.id,
                            onToggle: { store.toggle(item.id) },
                            onBeginEdit: { editingID = item.id },
                            onCommit: { title in
                                store.rename(item.id, to: title)
                                editingID = nil
                            },
                            onCancel: { editingID = nil },
                            onDelete: {
                                if editingID == item.id { editingID = nil }
                                store.remove(item.id)
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.vertical, 4)
                .animation(
                    .spring(response: 0.3, dampingFraction: 0.85),
                    value: store.document.items
                )
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if !store.document.items.isEmpty {
                Text("\(store.document.completedCount) of \(store.document.items.count) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 8)

            Button {
                store.revealInFinder()
            } label: {
                Text("TODO.md")
                    .font(.caption)
            }
            .buttonStyle(.link)
            .disabled(!store.fileExists)
            .help(store.fileURL.path)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private func addTask() {
        // Created empty and focused straight away, so adding a task is one
        // click and then typing — no dialog in between.
        let id = store.add()
        editingID = id
    }
}

private struct TodoRowView: View {
    let item: TodoItem
    let isEditing: Bool
    let onToggle: () -> Void
    let onBeginEdit: () -> Void
    let onCommit: (String) -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(item.isDone ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 18, height: 18)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            if isEditing {
                InlineTextField(
                    text: item.title,
                    font: .systemFont(ofSize: 12),
                    wraps: true,
                    placeholder: "New Task",
                    onCommit: onCommit,
                    onCancel: onCancel
                )
            } else {
                Text(item.title.isEmpty ? "New Task" : item.title)
                    .font(.system(size: 12))
                    .strikethrough(item.isDone, color: .secondary)
                    .foregroundStyle(item.isDone ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    // A task is read more often than it is scanned, so long
                    // ones wrap onto more lines instead of scrolling sideways.
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { onBeginEdit() }
            }

            if isHovered && !isEditing {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Delete")
            }
        }
        // Two spaces of markdown indent read as one step of nesting here.
        .padding(.leading, 10 + CGFloat(item.indent) * 14)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(isHovered ? Color.primary.opacity(0.05) : .clear)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Rename…") { onBeginEdit() }
            Button(item.isDone ? "Mark as Not Completed" : "Mark as Completed") { onToggle() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}
