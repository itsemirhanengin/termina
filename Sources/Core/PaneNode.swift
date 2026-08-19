import Foundation

enum SplitAxis {
    /// Panes side by side (split right).
    case horizontal
    /// Panes stacked (split down).
    case vertical
}

/// Binary split tree for the panes inside one tab.
indirect enum PaneNode: Identifiable {
    case leaf(TerminalSession)
    case split(id: UUID, axis: SplitAxis, first: PaneNode, second: PaneNode)

    var id: UUID {
        switch self {
        case .leaf(let session): session.id
        case .split(let id, _, _, _): id
        }
    }

    var sessions: [TerminalSession] {
        switch self {
        case .leaf(let session): [session]
        case .split(_, _, let first, let second): first.sessions + second.sessions
        }
    }

    func contains(sessionID: UUID) -> Bool {
        sessions.contains { $0.id == sessionID }
    }

    /// Returns a new tree where the given leaf is split in two,
    /// with `newLeaf` as the second pane.
    func splitting(sessionID: UUID, axis: SplitAxis, newLeaf: TerminalSession) -> PaneNode {
        switch self {
        case .leaf(let session) where session.id == sessionID:
            return .split(id: UUID(), axis: axis, first: self, second: .leaf(newLeaf))
        case .leaf:
            return self
        case .split(let id, let ax, let first, let second):
            return .split(
                id: id,
                axis: ax,
                first: first.splitting(sessionID: sessionID, axis: axis, newLeaf: newLeaf),
                second: second.splitting(sessionID: sessionID, axis: axis, newLeaf: newLeaf)
            )
        }
    }

    /// Returns the tree without the given session; `nil` means the tree is now empty.
    func removing(sessionID: UUID) -> PaneNode? {
        switch self {
        case .leaf(let session):
            return session.id == sessionID ? nil : self
        case .split(let id, let axis, let first, let second):
            let newFirst = first.removing(sessionID: sessionID)
            let newSecond = second.removing(sessionID: sessionID)
            switch (newFirst, newSecond) {
            case (nil, nil): return nil
            case (let remaining?, nil): return remaining
            case (nil, let remaining?): return remaining
            case (let f?, let s?): return .split(id: id, axis: axis, first: f, second: s)
            }
        }
    }
}
