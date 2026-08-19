import Foundation

/// A project is a folder on disk that acts as a workspace root.
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var folderPath: String

    var folderURL: URL { URL(fileURLWithPath: folderPath) }

    init(folderURL: URL) {
        self.id = UUID()
        self.name = folderURL.lastPathComponent
        self.folderPath = folderURL.path
    }
}
