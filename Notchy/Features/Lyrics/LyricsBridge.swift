import Foundation

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

    /// Look up synced lyrics for a track. Returns nil if not found / network failed.
    func fetch(title: String, artist: String, album: String, duration: Double) async -> [LrcLine]? {
        guard !title.isEmpty, !artist.isEmpty else { return nil }

        // Build https://lrclib.net/api/get?track_name=...&artist_name=...&album_name=...&duration=...
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

        if let lines = await getExact(request: req), !lines.isEmpty { return lines }
        // Fall back to a less strict search — catches cases where album/duration
        // don't perfectly match the local file's metadata.
        return await searchFallback(title: title, artist: artist)
    }

    private func getExact(request: URLRequest) async -> [LrcLine]? {
        do {
            let (data, resp) = try await session.data(for: request)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
                return Self.parseLRC(synced)
            }
            return nil
        } catch {
            return nil
        }
    }

    private func searchFallback(title: String, artist: String) async -> [LrcLine]? {
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
            // Pick the first hit that actually has synced lyrics.
            for entry in arr {
                if let synced = entry["syncedLyrics"] as? String, !synced.isEmpty {
                    return Self.parseLRC(synced)
                }
            }
            return nil
        } catch {
            return nil
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
