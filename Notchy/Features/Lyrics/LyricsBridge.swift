import Foundation

/// Synced + plain lyrics for a track. Synced lines have meaningful `time`;
/// plain lines all have `time = 0` and are intended for static display.
struct LyricsBundle: Equatable, Sendable {
    var synced: [LrcLine]
    var plain: [LrcLine]

    var isEmpty: Bool { synced.isEmpty && plain.isEmpty }
    var hasSynced: Bool { !synced.isEmpty }

    static let empty = LyricsBundle(synced: [], plain: [])
}

/// Fetches synced lyrics from lrclib.net — a free, no-auth public LRC API.
/// Falls back to nil (no lyrics) silently. We never crash or block media playback.
actor LyricsBridge {

    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 6
        cfg.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: cfg)
    }

    /// Look up lyrics for a track. Prefers synced LRC (lrclib exact → lrclib search),
    /// then falls back to plain text (lrclib `plainLyrics`, then Apple Music
    /// AppleScript). Never returns `.empty` silently — always returns something
    /// the caller can render, even if just empty.
    func fetch(title: String, artist: String, album: String, duration: Double) async -> LyricsBundle {
        guard !title.isEmpty else { return .empty }

        if !artist.isEmpty {
            // 1. lrclib exact (track + artist + album + duration)
            if let bundle = await lrclibGet(title: title, artist: artist, album: album, duration: duration),
               bundle.hasSynced { return bundle }
            // 2. lrclib search (loose match)
            if let bundle = await lrclibSearch(title: title, artist: artist),
               bundle.hasSynced { return bundle }
            // 3. lrclib search returned plain lyrics?
            if let bundle = await lrclibSearch(title: title, artist: artist),
               !bundle.plain.isEmpty { return bundle }
            // 4. lrclib exact plain lyrics?
            if let bundle = await lrclibGet(title: title, artist: artist, album: album, duration: duration),
               !bundle.plain.isEmpty { return bundle }
        }

        // 5. Last resort: Apple Music AppleScript (plain only).
        if let plain = await appleMusicPlainLyrics() {
            return LyricsBundle(synced: [], plain: Self.linesFromPlain(plain))
        }
        return .empty
    }

    private func lrclibGet(title: String, artist: String, album: String, duration: Double) async -> LyricsBundle? {
        var comps = URLComponents(string: "https://lrclib.net/api/get")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]
        if !album.isEmpty { items.append(URLQueryItem(name: "album_name", value: album)) }
        if duration > 0 { items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded())))) }
        comps.queryItems = items
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Notchy/0.2 (https://github.com/OtaruTech/notchy)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return Self.bundleFromLrclibJSON(json)
        } catch {
            return nil
        }
    }

    private func lrclibSearch(title: String, artist: String) async -> LyricsBundle? {
        var comps = URLComponents(string: "https://lrclib.net/api/search")!
        comps.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Notchy/0.2 (https://github.com/OtaruTech/notchy)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
            // Prefer first entry with synced; else first with plain.
            for entry in arr where (entry["syncedLyrics"] as? String)?.isEmpty == false {
                return Self.bundleFromLrclibJSON(entry)
            }
            for entry in arr where (entry["plainLyrics"] as? String)?.isEmpty == false {
                return Self.bundleFromLrclibJSON(entry)
            }
            return nil
        } catch {
            return nil
        }
    }

    private static func bundleFromLrclibJSON(_ json: [String: Any]) -> LyricsBundle {
        var synced: [LrcLine] = []
        var plain: [LrcLine] = []
        if let s = json["syncedLyrics"] as? String, !s.isEmpty {
            synced = parseLRC(s)
        }
        if let p = json["plainLyrics"] as? String, !p.isEmpty {
            plain = linesFromPlain(p)
        }
        return LyricsBundle(synced: synced, plain: plain)
    }

    private static func linesFromPlain(_ raw: String) -> [LrcLine] {
        raw.split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            .map { LrcLine(time: 0, text: String($0).trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.text.isEmpty }
    }

    /// Best-effort: ask Apple Music for the current track's plain lyrics. Returns
    /// nil if Music isn't running, the property is empty, or AppleScript is denied.
    private func appleMusicPlainLyrics() async -> String? {
        await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            DispatchQueue.global(qos: .utility).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                task.arguments = ["-e", #"tell application "Music" to if it is running then if player state is not stopped then return lyrics of current track"#]
                let out = Pipe()
                task.standardOutput = out
                task.standardError = Pipe()
                do {
                    try task.run()
                    task.waitUntilExit()
                    let data = out.fileHandleForReading.readDataToEndOfFile()
                    let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let text, !text.isEmpty, !text.hasPrefix("error") {
                        cont.resume(returning: text)
                    } else {
                        cont.resume(returning: nil)
                    }
                } catch {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    /// Parse an `.lrc` document into timed lines.
    /// Handles `[mm:ss.xx]Text` and `[mm:ss]Text`. Multi-stamp lines like
    /// `[00:10.5][00:20.5]Lyric` produce two entries.
    nonisolated static func parseLRC(_ raw: String) -> [LrcLine] {
        var out: [LrcLine] = []
        let lines = raw.split(whereSeparator: { $0 == "\n" || $0 == "\r" })
        for line in lines {
            let s = String(line)
            // Extract leading [..] tags
            var stamps: [Double] = []
            var text = s
            while text.hasPrefix("[") {
                guard let end = text.firstIndex(of: "]") else { break }
                let tag = text[text.index(after: text.startIndex)..<end]
                if let t = parseStamp(String(tag)) { stamps.append(t) }
                text = String(text[text.index(after: end)...])
            }
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            // Skip empty / metadata-only / non-stamped tags.
            guard !stamps.isEmpty else { continue }
            for stamp in stamps {
                // Empty text is allowed — represents an instrumental break / silence cue.
                out.append(LrcLine(time: stamp, text: trimmed))
            }
        }
        return out.sorted { $0.time < $1.time }
    }

    /// Parse `mm:ss.xx` / `mm:ss` / `mm:ss.xxx` into seconds.
    private static func parseStamp(_ s: String) -> Double? {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let mm = Int(parts[0]) else { return nil }
        let secondsField = String(parts[1])
        guard let secs = Double(secondsField) else { return nil }
        return Double(mm) * 60 + secs
    }
}
