/// Add new extensions here — one line per extension.
@MainActor
enum ExtensionRegistry {
    static let all: [AppExtension.Type] = [
        ThemesExtension.self,
        FileExplorerExtension.self,
        TodoExtension.self,
        SystemInfoExtension.self,
    ]
}
