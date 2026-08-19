import Observation

/// Keeps an AppKit view controller in sync with `@Observable` model state.
///
/// SwiftUI re-invokes `body` for you; AppKit has no such loop, so this
/// re-arms `withObservationTracking` after every change and runs `body`
/// again. Hold the token for as long as you want the updates; releasing
/// it stops them.
@MainActor
final class ObservationToken {
    private var isCancelled = false

    init(_ body: @escaping @MainActor () -> Void) {
        arm(body)
    }

    private func arm(_ body: @escaping @MainActor () -> Void) {
        withObservationTracking {
            body()
        } onChange: { [weak self] in
            // onChange fires inside the mutation; hop out before reading.
            Task { @MainActor [weak self] in
                guard let self, !self.isCancelled else { return }
                self.arm(body)
            }
        }
    }

    func cancel() {
        isCancelled = true
    }
}
