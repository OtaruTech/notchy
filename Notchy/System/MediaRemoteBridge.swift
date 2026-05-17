import Foundation

struct NowPlayingInfo: Equatable, Sendable {
    var title: String
    var artist: String?
    var album: String?
    var elapsed: Double?
    var duration: Double?
    var isPlaying: Bool
}

actor MediaRemoteBridge {

    private let handle: UnsafeMutableRawPointer?
    private let getInfoFn: GetInfoFn?
    private let registerFn: RegisterFn?

    private typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias RegisterFn = @convention(c) (DispatchQueue) -> Void

    init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        let h = dlopen(path, RTLD_NOW)
        self.handle = h
        if let h {
            let g = dlsym(h, "MRMediaRemoteGetNowPlayingInfo")
            self.getInfoFn = g.map { unsafeBitCast($0, to: GetInfoFn.self) }
            let r = dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications")
            self.registerFn = r.map { unsafeBitCast($0, to: RegisterFn.self) }
        } else {
            self.getInfoFn = nil
            self.registerFn = nil
        }
    }

    /// One-shot fetch.
    func fetch() async -> NowPlayingInfo? {
        guard let getInfoFn else { return nil }
        return await withCheckedContinuation { cont in
            getInfoFn(.main) { dict in
                cont.resume(returning: MediaRemoteBridge.parse(raw: dict))
            }
        }
    }

    /// Pure parser (testable without private API).
    nonisolated static func parse(raw: [String: Any]) -> NowPlayingInfo? {
        guard let title = raw["kMRMediaRemoteNowPlayingInfoTitle"] as? String,
              !title.isEmpty else { return nil }
        let artist = raw["kMRMediaRemoteNowPlayingInfoArtist"] as? String
        let album = raw["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
        let elapsed = raw["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double
        let duration = raw["kMRMediaRemoteNowPlayingInfoDuration"] as? Double
        let rate = (raw["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double) ?? 0
        return NowPlayingInfo(
            title: title, artist: artist, album: album,
            elapsed: elapsed, duration: duration,
            isPlaying: rate > 0
        )
    }

    /// Continuously yield current state changes via DistributedNotificationCenter.
    func changes() -> AsyncStream<NowPlayingInfo?> {
        AsyncStream { continuation in
            registerFn?(.main)
            let center = DistributedNotificationCenter.default()
            nonisolated(unsafe) let token = center.addObserver(
                forName: Notification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
                object: nil, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task {
                    let info = await self.fetch()
                    continuation.yield(info)
                }
            }
            // Initial value
            Task {
                let info = await self.fetch()
                continuation.yield(info)
            }
            continuation.onTermination = { _ in
                center.removeObserver(token)
            }
        }
    }
}
