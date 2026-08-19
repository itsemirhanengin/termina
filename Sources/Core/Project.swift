import Foundation

/// What the sidebar draws next to a project's name.
///
/// `.image` stores only a file name. The picture itself is copied into the
/// app's own storage on import, so deleting or moving the original never
/// empties the sidebar.
enum ProjectIcon: Codable, Hashable {
    case folder
    case emoji(String)
    case image(fileName: String)
}

/// A project is a folder on disk that acts as a workspace root.
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    /// Free to rename; it does not have to match the folder on disk.
    var name: String
    var folderPath: String
    var notes: String
    var icon: ProjectIcon

    var folderURL: URL { URL(fileURLWithPath: folderPath) }

    init(folderURL: URL) {
        self.id = UUID()
        self.name = folderURL.lastPathComponent
        self.folderPath = folderURL.path
        self.notes = ""
        self.icon = .folder
    }

    // Projects saved before icons and notes existed decode with defaults
    // rather than failing the whole snapshot.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        folderPath = try container.decode(String.self, forKey: .folderPath)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        icon = try container.decodeIfPresent(ProjectIcon.self, forKey: .icon) ?? .folder
    }
}
