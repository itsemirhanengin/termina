import AppKit
import SwiftUI

/// The field you get when renaming a file in Finder: it takes focus the moment
/// it appears, commits on Return and on losing focus, and abandons the edit on
/// Escape.
///
/// SwiftUI's `TextField` with `@FocusState` does not reliably report focus
/// leaving the SwiftUI hierarchy — clicking into the terminal, for instance —
/// which left renames stranded in edit mode. `NSTextField` reports exactly
/// that moment through `controlTextDidEndEditing`.
struct InlineTextField: NSViewRepresentable {
    let text: String
    var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    var alignment: NSTextAlignment = .natural
    /// Long text reads better on several lines than scrolled sideways.
    var wraps: Bool = false
    var placeholder: String = ""
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.delegate = context.coordinator
        field.font = font
        field.alignment = alignment
        field.placeholderString = placeholder
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = !wraps
        field.lineBreakMode = wraps ? .byWordWrapping : .byTruncatingTail
        field.cell?.wraps = wraps
        field.cell?.isScrollable = !wraps
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)

        DispatchQueue.main.async {
            guard let window = field.window else { return }
            window.makeFirstResponder(field)
            field.currentEditor()?.selectAll(nil)
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only the callbacks are refreshed; rewriting `stringValue` here would
        // fight whatever the user is typing.
        context.coordinator.parent = self
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextField, context: Context) -> CGSize? {
        guard wraps, let width = proposal.width, width > 0 else { return nil }
        nsView.preferredMaxLayoutWidth = width
        let fitting = nsView.sizeThatFits(
            NSSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: fitting.height)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: InlineTextField
        /// Return ends editing, which then also fires `controlTextDidEndEditing`
        /// — without this the edit would be committed twice.
        private var hasFinished = false

        init(_ parent: InlineTextField) {
            self.parent = parent
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard !hasFinished, let field = notification.object as? NSTextField else { return }
            hasFinished = true
            parent.onCommit(field.stringValue)
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                guard !hasFinished else { return true }
                hasFinished = true
                parent.onCommit(textView.string)
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                guard !hasFinished else { return true }
                hasFinished = true
                parent.onCancel()
                return true
            default:
                return false
            }
        }
    }
}
