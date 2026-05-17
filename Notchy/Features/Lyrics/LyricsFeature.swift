import Foundation
import Observation

/// Owns the cached LRC lines for the currently-loaded track. Re-fetches whenever
/// the (title, artist) pair changes. Holds nil when no lyrics are available so
/// the UI can hide the panel gracefully.
@MainActor
@Observable
final class LyricsFeature {

    private(set) var lines: [LrcLine] = []
    private(set) var trackKey: String = ""  // "title|artist"

    private let bridge: LyricsBridge
    private weak var mediaFeature: MediaFeature?
    private var observationTask: Task<Void, Never>?

    init(bridge: LyricsBridge, mediaFeature: MediaFeature) {
        self.bridge = bridge
        self.mediaFeature = mediaFeature
    }

    /// Start polling MediaFeature for track changes (Observation-based).
    func start() {
        scheduleObserve()
    }

    private func scheduleObserve() {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await withObservationTracking {
                _ = self.mediaFeature?.current?.title
                _ = self.mediaFeature?.current?.artist
            } onChange: {
                Task { @MainActor [weak self] in self?.handleTrackChange() }
            }
        }
    }

    private func handleTrackChange() {
        // Re-arm Observation tracking for the next change.
        scheduleObserve()

        guard let vm = mediaFeature?.current else {
            lines = []
            trackKey = ""
            return
        }
        let key = "\(vm.title)|\(vm.artist)"
        guard key != trackKey else { return }
        trackKey = key
        let title = vm.title
        let artist = vm.artist
        let album = vm.album
        let duration = vm.duration
        Task { @MainActor [weak self] in
            let fetched = await self?.bridge.fetch(
                title: title, artist: artist, album: album, duration: duration
            ) ?? []
            // Only apply if the track hasn't changed under us.
            guard self?.trackKey == key else { return }
            self?.lines = fetched
        }
    }

    /// The index of the currently-active LRC line at the given elapsed time.
    /// Returns nil if no lyrics or before the first stamp.
    func currentIndex(at elapsed: Double) -> Int? {
        guard !lines.isEmpty else { return nil }
        var idx: Int? = nil
        for (i, line) in lines.enumerated() {
            if line.time <= elapsed { idx = i } else { break }
        }
        return idx
    }
}
