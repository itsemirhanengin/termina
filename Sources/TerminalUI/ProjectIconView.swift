import AppKit
import SwiftUI

/// Draws a project's icon at a given point size. Falls back to the folder
/// symbol when a stored picture has gone missing, so a row never renders empty.
struct ProjectIconView: View {
    let icon: ProjectIcon
    var size: CGFloat = 16

    var body: some View {
        switch icon {
        case .folder:
            Image(systemName: "folder")
                .font(.system(size: size * 0.85))
                .frame(width: size, height: size)

        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: size * 0.9))
                .frame(width: size, height: size)

        case .image(let fileName):
            if let stored = ProjectIconStore.image(named: fileName) {
                Image(nsImage: stored)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            } else {
                Image(systemName: "folder")
                    .font(.system(size: size * 0.85))
                    .frame(width: size, height: size)
            }
        }
    }
}
