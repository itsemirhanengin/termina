import AppKit
import SwiftUI

/// Sheet for renaming a project, describing it, and choosing its icon.
struct ProjectEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let project: Project
    let onSave: (Project) -> Void

    private enum IconKind: String, CaseIterable, Identifiable {
        case folder, emoji, image
        var id: String { rawValue }
        var label: String {
            switch self {
            case .folder: "Folder"
            case .emoji: "Emoji"
            case .image: "Image"
            }
        }
    }

    @State private var name: String
    @State private var notes: String
    @State private var kind: IconKind
    @State private var emoji: String
    /// Set when a new picture is imported; the old one is only deleted once
    /// the user actually saves.
    @State private var importedFileName: String?
    @State private var existingFileName: String?
    @FocusState private var emojiFieldFocused: Bool

    init(project: Project, onSave: @escaping (Project) -> Void) {
        self.project = project
        self.onSave = onSave
        _name = State(initialValue: project.name)
        _notes = State(initialValue: project.notes)
        switch project.icon {
        case .folder:
            _kind = State(initialValue: .folder)
            _emoji = State(initialValue: "")
            _existingFileName = State(initialValue: nil)
        case .emoji(let value):
            _kind = State(initialValue: .emoji)
            _emoji = State(initialValue: value)
            _existingFileName = State(initialValue: nil)
        case .image(let fileName):
            _kind = State(initialValue: .image)
            _emoji = State(initialValue: "")
            _existingFileName = State(initialValue: fileName)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Icon") {
                        HStack(spacing: 12) {
                            ProjectIconView(icon: previewIcon, size: 40)
                                .frame(width: 40, height: 40)
                            iconControls
                        }
                    }
                }

                Section {
                    TextField("Name", text: $name)
                    TextField("Description", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    Text(project.folderPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 420)
    }

    @ViewBuilder
    private var iconControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $kind) {
                ForEach(IconKind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch kind {
            case .folder:
                Text("Uses the system folder symbol.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .emoji:
                HStack(spacing: 8) {
                    TextField("", text: $emoji)
                        .frame(width: 52)
                        .multilineTextAlignment(.center)
                        .focused($emojiFieldFocused)
                        .onChange(of: emoji) { _, newValue in
                            // One character is an icon; a sentence is not.
                            emoji = String(newValue.suffix(1))
                        }
                    Button("Browse…") {
                        emojiFieldFocused = true
                        NSApp.orderFrontCharacterPalette(nil)
                    }
                    .help("Open the system emoji picker (⌃⌘Space)")
                }

            case .image:
                HStack(spacing: 8) {
                    Button(currentImageFileName == nil ? "Choose Image…" : "Replace…") {
                        chooseImage()
                    }
                    if currentImageFileName != nil {
                        Text("Copied into Termina")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var currentImageFileName: String? { importedFileName ?? existingFileName }

    /// What the preview shows for the currently selected kind.
    private var previewIcon: ProjectIcon {
        switch kind {
        case .folder: .folder
        case .emoji: emoji.isEmpty ? .folder : .emoji(emoji)
        case .image: currentImageFileName.map { .image(fileName: $0) } ?? .folder
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Choose"
        panel.message = "Choose a picture for this project"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let fileName = ProjectIconStore.importImage(from: url) else {
            NSSound.beep()
            return
        }
        // Replacing a not-yet-saved import: drop the orphan straight away.
        if let previous = importedFileName { ProjectIconStore.delete(fileName: previous) }
        importedFileName = fileName
    }

    private func cancel() {
        if let importedFileName { ProjectIconStore.delete(fileName: importedFileName) }
        dismiss()
    }

    private func save() {
        var updated = project
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.icon = previewIcon

        // Any stored picture the saved icon no longer points at is garbage.
        if case .image(let keptFileName) = updated.icon {
            for candidate in [importedFileName, existingFileName].compactMap({ $0 })
            where candidate != keptFileName {
                ProjectIconStore.delete(fileName: candidate)
            }
        } else {
            for candidate in [importedFileName, existingFileName].compactMap({ $0 }) {
                ProjectIconStore.delete(fileName: candidate)
            }
        }

        onSave(updated)
        dismiss()
    }
}
