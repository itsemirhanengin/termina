import AppKit
import SwiftTerm

/// Makes ⇧⏎ insert a newline instead of submitting.
///
/// A pty carries no modifier information: AppKit folds ⇧⏎ into a plain
/// newline insertion, so SwiftTerm writes a bare CR and TUIs that treat ⏎ as
/// "submit" (Claude Code, Codex, aider) send the prompt instead of adding a
/// line. The fix is what iTerm2 and VS Code apply when their setup helpers
/// bind the key: emit ESC + CR, i.e. meta-Return. ⌥⏎ already produces that
/// sequence through SwiftTerm's `optionAsMetaKey` path, which is why it works
/// today while ⇧⏎ does not.
///
/// This runs as a local event monitor rather than a `keyDown` override
/// because SwiftTerm declares `keyDown` `public` but not `open` — it cannot
/// be overridden from outside the package.
@MainActor
enum ShiftReturnKeyMonitor {
    private static var monitor: Any?
    private static let metaReturn: [UInt8] = [0x1b, 0x0d]

    static func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let terminal = shiftReturnTarget(for: event) else { return event }
            terminal.send(metaReturn)
            return nil
        }
    }

    /// The focused terminal, when this event is ⇧⏎ (main or keypad Return)
    /// with no other modifier held. Bows out once the running program has
    /// switched on the Kitty keyboard protocol: it then asked for full key
    /// reports, and SwiftTerm's own encoding already tells shifted Return
    /// apart.
    private static func shiftReturnTarget(for event: NSEvent) -> TerminalView? {
        guard event.keyCode == 36 || event.keyCode == 76 else { return nil }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.shift),
              flags.isDisjoint(with: [.command, .control, .option])
        else { return nil }

        guard let terminal = event.window?.firstResponder as? TerminalView,
              terminal.getTerminal().keyboardEnhancementFlags.isEmpty
        else { return nil }
        return terminal
    }
}
