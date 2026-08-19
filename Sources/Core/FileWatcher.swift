import Foundation

/// Reports when a file changes on disk.
///
/// Editors and agents usually save by writing a temporary file and renaming it
/// over the original, which invalidates the descriptor — so a rename or delete
/// re-arms the watch on the new file rather than going silent.
final class FileWatcher {
    private let url: URL
    private let onChange: @Sendable () -> Void
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.itsemirhanengin.termina.filewatcher")

    init(url: URL, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.onChange = onChange
        start()
    }

    deinit {
        source?.cancel()
    }

    private func start() {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            // The file may not exist yet; nothing to watch until it does.
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data
            self.onChange()
            if flags.contains(.rename) || flags.contains(.delete) {
                self.rearm()
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    private func rearm() {
        source?.cancel()
        source = nil
        // Give the replacing write a moment to land before reopening.
        queue.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.start()
            self?.onChange()
        }
    }
}
