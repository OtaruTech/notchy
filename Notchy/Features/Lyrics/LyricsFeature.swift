import Foundation
import Observation

fileprivate func _lyLog(_ msg: String) {
    guard UserDefaults.standard.bool(forKey: "notchy.debugLogging") else { return }
    let line = "\(Date()) [Notchy.Lyrics] \(msg)\n"
    let path = "/tmp/notchy.log"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: path),
           let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            h.seekToEndOfFile()
            try? h.write(contentsOf: data)
            try? h.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

/// Owns the cached lyrics for the currently-loaded track. Re-fetches whenever
/// the (title, artist) pair changes. Holds an empty bundle when no lyrics are
/// available so the UI can hide the panel gracefully.
@MainActor
@Observable
final class LyricsFeature {

    private(set) var bundle: LyricsBundle = .empty
    private(set) var trackKey: String = ""  // "title|artist"

    var lines: [LrcLine] { bundle.synced }
    var plainLines: [LrcLine] { bundle.plain }
    var hasSynced: Bool { bundle.hasSynced }
    var hasAny: Bool { !bundle.isEmpty }

    private let bridge: LyricsBridge
    private weak var mediaFeature: MediaFeature?
    private var observationTask: Task<Void, Never>?

    init(bridge: LyricsBridge, mediaFeature: MediaFeature) {
        self.bridge = bridge
        self.mediaFeature = mediaFeature
    }

    /// Start polling MediaFeature for track changes (Observation-based).
    func start() {
        _lyLog("LyricsFeature.start()")
        scheduleObserve()
        // Kick once in case media already has a track loaded before we attached.
        handleTrackChange()
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
            bundle = .empty
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
        _lyLog("track change → \(title) / \(artist) (album=\(album), dur=\(duration))")
        Task { @MainActor [weak self] in
            let fetched = await self?.bridge.fetch(
                title: title, artist: artist, album: album, duration: duration
            ) ?? .empty
            // Only apply if the track hasn't changed under us.
            guard self?.trackKey == key else {
                _lyLog("dropped result: track changed during fetch")
                return
            }
            _lyLog("fetched: synced=\(fetched.synced.count) plain=\(fetched.plain.count) for \(title)")
            self?.bundle = fetched
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
