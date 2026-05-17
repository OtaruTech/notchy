import Foundation

/// Append a line to /tmp/notchy.log for debugging (NSLog/print don't reliably
/// reach `log show` from sandbox-free Swift apps on recent macOS).
fileprivate func _debugLog(_ msg: String) {
    let line = "\(Date()) \(msg)\n"
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

enum MRCommand: String {
    case play
    case pause
    case togglePlayPause = "toggle-play-pause"
    case next
    case previous
}

struct NowPlayingInfo: Equatable, Sendable {
    var title: String
    var artist: String?
    var album: String?
    var elapsed: Double?
    var duration: Double?
    var isPlaying: Bool
    /// Decoded JPEG/PNG bytes (small enough — typically <200KB).
    var artworkData: Data?
    /// e.g. com.apple.Music, com.google.Chrome
    var bundleIdentifier: String?
}

/// Talks to the `media-control` CLI tool (https://github.com/ungive/mediaremote-adapter)
/// to get Now Playing data. The CLI bypasses macOS 15.4+ TCC restrictions on
/// `MediaRemote.framework` by running its private-framework loader inside an Apple-signed
/// `/usr/bin/perl` (whose bundle id `com.apple.perl5` is entitled).
///
/// Requires `media-control` on `$PATH`. Install via: `brew install media-control`.
/// Future: bundle the CLI inside Notchy.app so end users don't need brew.
actor MediaRemoteBridge {

    /// Where to look for the `media-control` binary, in order.
    /// The bundled copy lives at .app/Contents/Resources/MediaControl/bin/media-control —
    /// no brew install required for end users.
    private static var binaryCandidates: [String] {
        var paths: [String] = []
        if let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("MediaControl/bin/media-control", isDirectory: false)
            .path {
            paths.append(bundled)
        }
        paths.append("/opt/homebrew/bin/media-control")  // Apple Silicon brew
        paths.append("/usr/local/bin/media-control")     // Intel brew
        return paths
    }

    static func binaryPath() -> String? {
        binaryCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    init() {}

    /// One-shot fetch via `media-control get`.
    func fetch() async -> NowPlayingInfo? {
        guard let bin = Self.binaryPath() else { return nil }
        return await withCheckedContinuation { cont in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: bin)
            proc.arguments = ["get"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: MediaRemoteBridge.parse(jsonData: data))
            } catch {
                cont.resume(returning: nil)
            }
        }
    }

    /// Send a control command via `media-control <command>`.
    @discardableResult
    func send(_ command: MRCommand) -> Bool {
        guard let bin = Self.binaryPath() else { return false }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = [command.rawValue]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Parse media-control JSON output (handles both raw payload and stream `{"type","payload"}` envelope).
    nonisolated static func parse(jsonData: Data) -> NowPlayingInfo? {
        guard let any = try? JSONSerialization.jsonObject(with: jsonData),
              let dict = any as? [String: Any]
        else { return nil }
        // Stream envelope: {"type":"data","diff":bool,"payload":{...}}
        let payload: [String: Any]
        if let p = dict["payload"] as? [String: Any] {
            payload = p
        } else {
            payload = dict
        }
        return parse(payload: payload)
    }

    nonisolated static func parse(payload: [String: Any]) -> NowPlayingInfo? {
        guard let title = payload["title"] as? String, !title.isEmpty else { return nil }
        let artist = payload["artist"] as? String
        let albumRaw = payload["album"] as? String
        let album = (albumRaw?.isEmpty == false) ? albumRaw : nil
        let elapsed = payload["elapsedTime"] as? Double
        let duration = payload["duration"] as? Double
        let playing = (payload["playing"] as? Bool) ?? ((payload["playbackRate"] as? Double).map { $0 > 0 } ?? false)
        // Artwork is base64-encoded JPEG/PNG in the JSON payload.
        let artworkData: Data?
        if let b64 = payload["artworkData"] as? String, !b64.isEmpty {
            artworkData = Data(base64Encoded: b64, options: .ignoreUnknownCharacters)
        } else {
            artworkData = nil
        }
        return NowPlayingInfo(
            title: title,
            artist: artist,
            album: album,
            elapsed: elapsed,
            duration: duration,
            isPlaying: playing,
            artworkData: artworkData,
            bundleIdentifier: payload["bundleIdentifier"] as? String
        )
    }

    /// Stream Now Playing changes by reading `media-control stream` line by line.
    /// Yields nil when no media is playing.
    ///
    /// `media-control stream` emits two kinds of events:
    /// - `{"type":"data","diff":false,"payload":{...full...}}` — initial / full snapshot
    /// - `{"type":"data","diff":true,"payload":{...partial...}}` — only the changed fields
    /// Bridge maintains a merged state so partial diffs (e.g. just `{"playing":false}`)
    /// don't drop the rest of the now-playing info.
    func changes() -> AsyncStream<NowPlayingInfo?> {
        AsyncStream { continuation in
            guard let bin = Self.binaryPath() else {
                continuation.finish()
                return
            }
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: bin)
            proc.arguments = ["stream"]
            let outPipe = Pipe()
            proc.standardOutput = outPipe
            proc.standardError = Pipe()

            let handle = outPipe.fileHandleForReading
            nonisolated(unsafe) var buffer = Data()
            nonisolated(unsafe) var merged: [String: Any] = [:]
            handle.readabilityHandler = { fh in
                let chunk = fh.availableData
                if chunk.isEmpty {
                    fh.readabilityHandler = nil
                    return
                }
                buffer.append(chunk)
                while let nl = buffer.firstIndex(of: 0x0A) {
                    let line = buffer.subdata(in: 0..<nl)
                    buffer.removeSubrange(0...nl)
                    guard !line.isEmpty else { continue }
                    guard let env = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
                    let isDiff = (env["diff"] as? Bool) ?? false
                    let payload = (env["payload"] as? [String: Any]) ?? [:]
                    if isDiff {
                        // Merge partial diff on top of existing state.
                        for (k, v) in payload { merged[k] = v }
                    } else {
                        // Full replacement (`diff:false`). Empty payload means "nothing playing".
                        merged = payload
                    }
                    let info = MediaRemoteBridge.parse(payload: merged)
                    _debugLog("[Notchy.MediaBridge] event diff=\(isDiff) keys=\(Array(payload.keys).prefix(4)) -> title=\(info?.title ?? "<nil>") playing=\(info?.isPlaying ?? false)")
                    continuation.yield(info)
                }
            }
            _debugLog("[Notchy.MediaBridge] launching: \(bin) stream")

            do {
                try proc.run()
                _debugLog("[Notchy.MediaBridge] spawned pid=\(proc.processIdentifier)")
            } catch {
                _debugLog("[Notchy.MediaBridge] spawn FAILED: \(error)")
                continuation.finish()
                return
            }

            continuation.onTermination = { _ in
                proc.terminate()
                handle.readabilityHandler = nil
            }
        }
    }
}
