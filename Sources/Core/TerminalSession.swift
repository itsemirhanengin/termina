import AppKit
import Observation
import SwiftTerm

/// One live shell. Owns the SwiftTerm view so the process and scrollback
/// survive tab/project switches — SwiftUI only re-attaches the same NSView.
@MainActor
@Observable
final class TerminalSession: Identifiable {
    let id = UUID()
    let folderURL: URL
    private(set) var title: String = ""
    private(set) var isTerminated = false

    @ObservationIgnored var onTerminated: ((TerminalSession) -> Void)?
    @ObservationIgnored let terminalView: LocalProcessTerminalView

    init(folderURL: URL, theme: TerminalTheme, fontSize: CGFloat) {
        self.folderURL = folderURL
        self.terminalView = LocalProcessTerminalView(
            frame: NSRect(x: 0, y: 0, width: 800, height: 600)
        )
        terminalView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        theme.apply(to: terminalView)
        terminalView.processDelegate = self
        startShell()
    }

    private func startShell() {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shellName = (shell as NSString).lastPathComponent

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["TERM_PROGRAM"] = "Termina"
        let envList = env.map { "\($0.key)=\($0.value)" }

        // execName "-zsh" makes the shell a login shell.
        terminalView.startProcess(
            executable: shell,
            args: [],
            environment: envList,
            execName: "-\(shellName)",
            currentDirectory: folderURL.path
        )
    }

    func focus() {
        terminalView.window?.makeFirstResponder(terminalView)
    }

    func sendText(_ text: String) {
        terminalView.send(txt: text)
    }

    /// Force-kill the shell (⌘W). `processTerminated` fires afterwards.
    /// SIGHUP, not SIGTERM: interactive shells ignore SIGTERM but exit on
    /// hangup, matching what closing a Terminal.app window does.
    func terminate() {
        guard !isTerminated else { return }
        let pid = terminalView.process.shellPid
        if pid > 0 {
            kill(pid, SIGHUP)
        } else {
            terminalView.terminate()
        }
    }
}

extension TerminalSession: @preconcurrency LocalProcessTerminalViewDelegate {
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        self.title = title
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        guard !isTerminated else { return }
        isTerminated = true
        onTerminated?(self)
    }
}
