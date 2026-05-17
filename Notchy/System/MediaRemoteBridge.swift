import Foundation

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
    private static let binaryCandidates = [
        "/opt/homebrew/bin/media-control",  // Apple Silicon brew
        "/usr/local/bin/media-control",     // Intel brew
        "/usr/bin/media-control",           // future bundled path
    ]

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
        return NowPlayingInfo(
            title: title,
            artist: artist,
            album: album,
            elapsed: elapsed,
            duration: duration,
            isPlaying: playing
        )
    }

    /// Stream Now Playing changes by reading `media-control stream` line by line.
    /// Yields nil when no media is playing.
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
            handle.readabilityHandler = { fh in
                let chunk = fh.availableData
                if chunk.isEmpty {
                    fh.readabilityHandler = nil
                    return
                }
                buffer.append(chunk)
                // Split on newlines; keep trailing partial line in buffer.
                while let nl = buffer.firstIndex(of: 0x0A) {
                    let line = buffer.subdata(in: 0..<nl)
                    buffer.removeSubrange(0...nl)
                    guard !line.isEmpty else { continue }
                    let info = MediaRemoteBridge.parse(jsonData: line)
                    continuation.yield(info)
                }
            }

            do {
                try proc.run()
            } catch {
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
