import AppKit
import SwiftTerm

/// A terminal color palette. Extensions register these via
/// `ExtensionContext.registerTheme(_:)`.
struct TerminalTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let isDark: Bool
    /// Hex strings like "#282C34".
    let background: String
    let foreground: String
    let cursor: String
    let selection: String
    /// Optional alpha for the selection color (macOS selections are translucent).
    var selectionAlpha: CGFloat = 0.45
    /// The 16 ANSI colors: normal 0-7, bright 8-15.
    let ansi: [String]

    @MainActor
    func apply(to view: TerminalView) {
        view.nativeBackgroundColor = NSColor(hex: background)
        view.nativeForegroundColor = NSColor(hex: foreground)
        view.caretColor = NSColor(hex: cursor)
        view.selectedTextBackgroundColor = NSColor(hex: selection).withAlphaComponent(selectionAlpha)
        view.installColors(ansi.map { SwiftTerm.Color(hex: $0) })
        view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        view.needsDisplay = true
    }
}

extension NSColor {
    convenience init(hex: String) {
        let (r, g, b) = hexComponents(hex)
        self.init(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1
        )
    }
}

extension SwiftTerm.Color {
    convenience init(hex: String) {
        let (r, g, b) = hexComponents(hex)
        self.init(
            red: UInt16(r) * 257,
            green: UInt16(g) * 257,
            blue: UInt16(b) * 257
        )
    }
}

private func hexComponents(_ hex: String) -> (UInt8, UInt8, UInt8) {
    var value: UInt64 = 0
    let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    Scanner(string: cleaned).scanHexInt64(&value)
    return (
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF)
    )
}
