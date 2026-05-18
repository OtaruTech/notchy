import Foundation
import Observation

/// Owns the currently-visible HUD event (or `nil`). System monitors push
/// events via `show(_:)`; the feature auto-clears `current` after the
/// configured duration so the SwiftUI strip can fade itself out.
@MainActor
@Observable
final class HUDFeature {

    private(set) var current: HUDEvent?

    /// Last-shown timestamp so a stream of key presses extends the dismiss
    /// timer instead of stuttering.
    private var dismissTask: Task<Void, Never>?

    func show(_ event: HUDEvent) {
        // Respect per-kind Settings toggle. Default ON so a fresh install
        // demonstrates the feature.
        let enabled = UserDefaults.standard.object(forKey: event.kind.enabledKey) as? Bool ?? true
        guard enabled else { return }

        current = event

        let stored = UserDefaults.standard.object(forKey: "notchy.hudDuration")
        let duration: Double
        if let n = stored as? NSNumber { duration = n.doubleValue }
        else if let d = stored as? Double { duration = d }
        else { duration = 1.5 }
        let clamped = max(0.4, min(6.0, duration))

        dismissTask?.cancel()
        let captured = event
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(clamped))
            // try? swallows CancellationError but doesn't early-exit, so
            // cancelled tasks otherwise wipe `current` right after the cancel
            // (multi-listener rapid-fire bug). Check isCancelled explicitly.
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if self.current == captured { self.current = nil }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}
