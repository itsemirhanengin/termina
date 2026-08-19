import AppKit
import Foundation
import Observation

/// Reads and writes one project's `TODO.md`.
///
/// The file is the source of truth, not this object: an agent working in the
/// terminal edits `TODO.md` directly and the panel follows along, which is the
/// whole reason the list lives in the repository instead of in app storage.
@MainActor
@Observable
final class TodoStore {
    let fileURL: URL
    private(set) var document: TodoDocument
    /// `false` until the first task is added — nothing is written to a project
    /// just because its panel was opened.
    private(set) var fileExists: Bool

    @ObservationIgnored private var watcher: FileWatcher?
    /// What was last written or read, so the app ignores the change
    /// notification caused by its own save.
    @ObservationIgnored private var knownText: String

    init(folderURL: URL) {
        fileURL = folderURL.appendingPathComponent(TodoDocument.fileName)
        let text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        knownText = text
        document = TodoDocument(text: text)
        startWatching(folderURL: folderURL)
    }

    // MARK: Editing

    func toggle(_ id: TodoItem.ID) {
        guard let item = document.items.first(where: { $0.id == id }) else { return }
        document.setDone(!item.isDone, for: id)
        save()
    }

    func rename(_ id: TodoItem.ID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // An emptied task is a deleted task; leaving `- [ ]` behind would be
        // noise in the file.
        if trimmed.isEmpty {
            remove(id)
            return
        }
        document.setTitle(trimmed, for: id)
        save()
    }

    @discardableResult
    func add(title: String = "") -> TodoItem.ID {
        let id = document.append(title: title)
        save()
        return id
    }

    func remove(_ id: TodoItem.ID) {
        document.remove(id)
        save()
    }

    func move(from source: Int, to destination: Int) {
        document.move(from: source, to: destination)
        save()
    }

    func revealInFinder() {
        guard fileExists else { return }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    // MARK: Disk

    private func save() {
        let text = document.text
        knownText = text
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            fileExists = true
        } catch {
            // Read-only folder or a vanished project — the in-memory list still
            // reflects what the user did; the next save can succeed.
            fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        }
    }

    private func reloadFromDisk() {
        let text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        guard text != knownText else { return }
        knownText = text
        fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        document = TodoDocument(text: text)
    }

    /// Watches the folder as well as the file: the file may not exist yet, and
    /// a folder event is how its creation shows up.
    private func startWatching(folderURL: URL) {
        let reload: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in self?.reloadFromDisk() }
        }
        watcher = FileWatcher(url: fileExists ? fileURL : folderURL, onChange: reload)
    }
}

/// One store per project folder, so the panel keeps its list when you leave a
/// project and come back.
@MainActor
enum TodoStoreRegistry {
    private static var stores: [String: TodoStore] = [:]

    static func store(for folderURL: URL) -> TodoStore {
        let key = folderURL.standardizedFileURL.path
        if let existing = stores[key] { return existing }
        let store = TodoStore(folderURL: folderURL)
        stores[key] = store
        return store
    }
}
