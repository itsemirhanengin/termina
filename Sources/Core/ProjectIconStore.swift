import AppKit

/// Owns the copies of user-picked project images.
///
/// Importing re-encodes the picture into a square PNG inside Application
/// Support and hands back a bare file name. Nothing ever points at the file
/// the user chose, so the icon survives that file being moved or deleted.
enum ProjectIconStore {
    /// Icons are square and small; the sidebar draws them at 16pt, the editor
    /// at 40pt, and Retina doubles both.
    private static let storedSize: CGFloat = 256

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base
            .appendingPathComponent("Termina", isDirectory: true)
            .appendingPathComponent("ProjectIcons", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(forFileName fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    /// Copies the picture in and returns its stored file name, or `nil` if the
    /// file could not be read as an image.
    static func importImage(from sourceURL: URL) -> String? {
        guard let source = NSImage(contentsOf: sourceURL) else { return nil }
        guard let png = squarePNG(from: source) else { return nil }

        // A fresh name per import: reusing one would let AppKit's image cache
        // keep serving the previous picture.
        let fileName = "\(UUID().uuidString).png"
        do {
            try png.write(to: url(forFileName: fileName), options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    static func image(named fileName: String) -> NSImage? {
        NSImage(contentsOf: url(forFileName: fileName))
    }

    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(forFileName: fileName))
    }

    /// Deletes the stored picture behind an icon, if it has one.
    static func discardStoredImage(for icon: ProjectIcon) {
        if case .image(let fileName) = icon { delete(fileName: fileName) }
    }

    /// Centre-crops to a square and redraws at `storedSize`.
    private static func squarePNG(from image: NSImage) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let side = min(size.width, size.height)
        let crop = NSRect(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2,
            width: side,
            height: side
        )

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(storedSize), pixelsHigh: Int(storedSize),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )
        guard let rep else { return nil }
        rep.size = NSSize(width: storedSize, height: storedSize)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(x: 0, y: 0, width: storedSize, height: storedSize),
            from: crop,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }
}
