import Foundation

/// One checkbox line in `TODO.md`.
struct TodoItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    /// Nesting level, two spaces per level. Kept so agents can write sub-tasks
    /// without the app flattening them on the next save.
    var indent: Int
}

/// A parsed `TODO.md`.
///
/// The whole file is kept as lines and only the checkbox lines are understood.
/// Headings, prose, code fences and blank lines are carried through a round
/// trip byte for byte — an agent editing this file must never find its notes
/// rewritten because the app saved a checkbox.
struct TodoDocument: Equatable {
    private(set) var lines: [String]
    private(set) var items: [TodoItem]
    /// Index into `lines` for each entry of `items`.
    private(set) var lineIndexes: [Int]

    static let fileName = "TODO.md"

    /// What a brand-new file gets. The heading is what makes the file readable
    /// on GitHub and obvious to an agent opening it cold.
    private static let template = ["# TODO", ""]

    init(text: String) {
        lines = text.isEmpty ? Self.template : text.components(separatedBy: .newlines)
        items = []
        lineIndexes = []
        reindex(reusing: [])
    }

    var text: String { lines.joined(separator: "\n") }

    var completedCount: Int { items.filter(\.isDone).count }

    // MARK: Editing

    mutating func setDone(_ isDone: Bool, for id: TodoItem.ID) {
        guard let position = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items[position]
        item.isDone = isDone
        replaceLine(at: position, with: item)
    }

    mutating func setTitle(_ title: String, for id: TodoItem.ID) {
        guard let position = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items[position]
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        replaceLine(at: position, with: item)
    }

    /// Appends after the last checkbox so new work joins the existing list
    /// rather than landing under whatever section happens to be last.
    @discardableResult
    mutating func append(title: String) -> TodoItem.ID {
        let item = TodoItem(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            isDone: false,
            indent: 0
        )
        let insertionIndex = (lineIndexes.last.map { $0 + 1 }) ?? lines.count
        lines.insert(Self.render(item), at: insertionIndex)
        let previous = items
        reindex(reusing: previous)
        return items.first { $0.title == item.title && !$0.isDone }?.id ?? item.id
    }

    mutating func remove(_ id: TodoItem.ID) {
        guard let position = items.firstIndex(where: { $0.id == id }) else { return }
        lines.remove(at: lineIndexes[position])
        let previous = items
        reindex(reusing: previous)
    }

    mutating func move(from source: Int, to destination: Int) {
        guard lineIndexes.indices.contains(source),
              lineIndexes.indices.contains(destination),
              source != destination
        else { return }
        let line = lines.remove(at: lineIndexes[source])
        // Removing shifts every later line up by one.
        let target = lineIndexes[destination] - (destination > source ? 0 : 0)
        lines.insert(line, at: min(max(target, 0), lines.count))
        let previous = items
        reindex(reusing: previous)
    }

    private mutating func replaceLine(at position: Int, with item: TodoItem) {
        lines[lineIndexes[position]] = Self.render(item)
        items[position] = item
    }

    // MARK: Parsing

    /// Re-reads the checkbox lines. Identities are carried over from `previous`
    /// where the text still matches, so an edit made outside the app animates
    /// as a change rather than as the whole list being replaced.
    private mutating func reindex(reusing previous: [TodoItem]) {
        var parsed: [TodoItem] = []
        var indexes: [Int] = []
        var unclaimed = previous

        for (lineIndex, line) in lines.enumerated() {
            guard let task = Self.parse(line) else { continue }
            let reusedID: UUID
            if let match = unclaimed.firstIndex(where: { $0.title == task.title }) {
                reusedID = unclaimed[match].id
                unclaimed.remove(at: match)
            } else {
                reusedID = UUID()
            }
            parsed.append(
                TodoItem(id: reusedID, title: task.title, isDone: task.isDone, indent: task.indent)
            )
            indexes.append(lineIndex)
        }

        items = parsed
        lineIndexes = indexes
    }

    private struct ParsedTask {
        let indent: Int
        let isDone: Bool
        let title: String
    }

    /// Matches `- [ ] text`, `* [x] text`, `+ [X] text` at any indent.
    private static func parse(_ line: String) -> ParsedTask? {
        let body = line.drop { $0 == " " || $0 == "\t" }
        let indentWidth = line.count - body.count
        guard let bullet = body.first, "-*+".contains(bullet) else { return nil }

        var rest = body.dropFirst()
        guard rest.first == " " else { return nil }
        rest = rest.dropFirst()
        guard rest.first == "[" else { return nil }
        rest = rest.dropFirst()
        guard let mark = rest.first else { return nil }
        rest = rest.dropFirst()
        guard rest.first == "]" else { return nil }
        rest = rest.dropFirst()

        let isDone: Bool
        switch mark {
        case " ": isDone = false
        case "x", "X": isDone = true
        default: return nil
        }

        return ParsedTask(
            indent: indentWidth / 2,
            isDone: isDone,
            title: rest.trimmingCharacters(in: .whitespaces)
        )
    }

    private static func render(_ item: TodoItem) -> String {
        String(repeating: "  ", count: item.indent)
            + "- [\(item.isDone ? "x" : " ")] "
            + item.title
    }
}
