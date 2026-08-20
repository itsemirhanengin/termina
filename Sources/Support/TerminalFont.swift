import AppKit

/// Resolves the terminal's typeface from a stored family name.
///
/// The terminal used to hard-code `.monospacedSystemFont`, which is SF Mono.
/// SF Mono has no glyphs in the Private Use Area, so Powerline/Nerd Font
/// prompts (agnoster, starship, powerlevel10k) render their separators and
/// icons as tofu — CoreText's fallback only covers part of that range, so
/// some glyphs appear and others don't. Letting the user pick an installed
/// patched font fixes it at the source.
enum TerminalFont {
    /// Empty string means "whatever the system calls monospaced" — stored
    /// rather than a concrete name so the default tracks the OS.
    static let systemFamily = ""

    /// Substrings that mark a family as carrying Powerline glyphs, narrowest
    /// first. Matching on these rather than a fixed list of names means any
    /// patched font the user installs later is picked up too — the families
    /// are named by the patcher, not by us.
    private static let patchedMarkers = [
        "Nerd Font Mono",
        "Nerd Font",
        "for Powerline",
        "Powerline",
    ]

    /// Font families macOS reports as fixed-pitch, sorted for display.
    /// Nerd Font variants only appear here once they are actually installed.
    static func monospacedFamilies() -> [String] {
        NSFontManager.shared.availableFontFamilies
            .filter { isMonospaced($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// The family to start with when there is no stored preference: an
    /// installed Powerline-patched monospace if there is one, else the system
    /// default. Meslo wins ties only because it is what the setup guides
    /// install; any patched font works.
    static func defaultFamily() -> String {
        let candidates = monospacedFamilies()
        for marker in patchedMarkers {
            let matches = candidates.filter { $0.localizedCaseInsensitiveContains(marker) }
            if matches.isEmpty { continue }
            return matches.first { $0.hasPrefix("MesloLGS ") } ?? matches[0]
        }
        return systemFamily
    }

    static func resolve(family: String, size: CGFloat) -> NSFont {
        guard !family.isEmpty, let font = font(family: family, size: size) else {
            return .monospacedSystemFont(ofSize: size, weight: .regular)
        }
        return font
    }

    /// `NSFont(name:)` wants a PostScript name, so go through the font manager
    /// first — it takes a family name and picks the regular member.
    private static func font(family: String, size: CGFloat) -> NSFont? {
        NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size)
            ?? NSFont(name: family, size: size)
    }

    private static func isMonospaced(_ family: String) -> Bool {
        font(family: family, size: 12)?.isFixedPitch ?? false
    }
}
