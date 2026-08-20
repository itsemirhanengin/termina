import Foundation

/// A shell-reported window title, split into the status glyph a CLI prefixes
/// it with and the text underneath.
///
/// Agent CLIs put a glyph in front of the OSC title, and it means two
/// different things. Claude Code, measured over a pty:
///
///     idle     "✳ Claude Code"
///     working  "◐ Greeting message" → "◑ Greeting message" → "◐ …"
///     done     "✳ Greeting message"
///
/// So the rotating wedge is a spinner and the sparkle is just a badge that
/// sits there. Both are peeled off the title — a glyph in a tab reads as
/// noise — but only the spinner turns into a `ProgressView`.
struct ShellTitle {
    /// The title with any leading status glyph removed.
    let text: String
    /// True while the glyph is a spinner frame, i.e. the CLI is working.
    let isBusy: Bool

    init(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let afterGlyph = trimmed.dropFirst()
        let rest = afterGlyph.drop { $0.isWhitespace }

        // The glyph has to be a standalone prefix with a title behind it:
        // "◐ Greeting" is a status glyph, "*.swift" and "/Users/…" are just
        // titles that happen to start with a symbol.
        guard let first = trimmed.first,
              let glyph = Glyph(first),
              afterGlyph.first?.isWhitespace == true,
              !rest.isEmpty
        else {
            self.text = trimmed
            self.isBusy = false
            return
        }

        self.text = String(rest)
        self.isBusy = glyph == .spinner
    }

    private enum Glyph {
        /// A frame of an animation: the CLI is working.
        case spinner
        /// A glyph that sits still: branding, or a finished-state mark.
        case badge

        init?(_ character: Character) {
            if Self.spinnerFrames.contains(character) || character.isBraille {
                self = .spinner
            } else if Self.badges.contains(character) {
                self = .badge
            } else {
                return nil
            }
        }

        /// Pie and clock wedges — the sets CLIs animate. Braille is handled
        /// by range, since those spinners walk the whole block.
        private static let spinnerFrames: Set<Character> = [
            "◐", "◑", "◒", "◓",
            "◴", "◵", "◶", "◷",
            "◜", "◝", "◞", "◟",
            "▖", "▘", "▝", "▗",
        ]

        private static let badges: Set<Character> = [
            "·", "∗", "*", "✢", "✱", "✳", "✶", "✷", "✻", "✽", "✦", "✧",
            "●", "○", "◉", "◎", "◍", "◌", "◆", "◇",
            "✔", "✓", "✗", "✘", "⚠", "⏸", "⏵", "▸", "❯",
        ]
    }
}

private extension Character {
    /// U+2800–U+28FF, the Braille Patterns block used by dot spinners.
    var isBraille: Bool {
        guard unicodeScalars.count == 1, let scalar = unicodeScalars.first else { return false }
        return (0x2800...0x28FF).contains(Int(scalar.value))
    }
}
