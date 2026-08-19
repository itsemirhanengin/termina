import Foundation

/// Ships the built-in color palettes. Add a theme here (or write your own
/// extension that calls `registerTheme`) and it appears in Settings.
struct ThemesExtension: AppExtension {
    static let id = "co.bugece.termina.themes"
    static let name = "Built-in Themes"

    func activate(_ context: ExtensionContext) {
        context.registerTheme(TerminalTheme(
            id: "termina-dark",
            name: "Termina Dark",
            isDark: true,
            // Neutral greys, no blue cast: the terminal fills the detail area
            // edge to edge, so its background has to read as a continuation of
            // macOS' own dark chrome rather than a second, competing surface.
            background: "#262727",
            foreground: "#D4D4D8",
            cursor: "#4C8DFF",
            selection: "#434344",
            selectionAlpha: 0.85,
            ansi: [
                "#262727", "#E06C75", "#98C379", "#E5C07B",
                "#61AFEF", "#C678DD", "#56B6C2", "#D4D4D8",
                "#6E6E76", "#F0808A", "#A8D98A", "#F0CE8C",
                "#7CC0F5", "#D38CE8", "#6BC7D2", "#FFFFFF",
            ]
        ))

        context.registerTheme(TerminalTheme(
            id: "termina-light",
            name: "Termina Light",
            isDark: false,
            // White content on macOS' grey light chrome — the native
            // document-on-window relationship, inverted from the dark theme.
            background: "#FFFFFF",
            foreground: "#1F2328",
            cursor: "#044289",
            selection: "#0366D6",
            selectionAlpha: 0.25,
            ansi: [
                "#24292E", "#D73A49", "#22863A", "#B08800",
                "#0366D6", "#6F42C1", "#1B7C83", "#6A737D",
                "#959DA5", "#CB2431", "#28A745", "#DBAB09",
                "#2188FF", "#8A63D2", "#3192AA", "#D1D5DA",
            ]
        ))

        context.registerTheme(TerminalTheme(
            id: "midnight",
            name: "Midnight",
            isDark: true,
            background: "#282A36",
            foreground: "#F8F8F2",
            cursor: "#F8F8F2",
            selection: "#44475A",
            selectionAlpha: 0.8,
            ansi: [
                "#21222C", "#FF5555", "#50FA7B", "#F1FA8C",
                "#BD93F9", "#FF79C6", "#8BE9FD", "#F8F8F2",
                "#6272A4", "#FF6E6E", "#69FF94", "#FFFFA5",
                "#D6ACFF", "#FF92DF", "#A4FFFF", "#FFFFFF",
            ]
        ))
    }
}
