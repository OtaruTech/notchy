import Foundation

/// Pure-function extractor that finds the first joinable meeting URL in an
/// EventKit event's location, notes, or url fields. Recognises the major
/// videoconferencing providers used in practice:
///   - Lark / 飞书
///   - Zoom
///   - Google Meet
///   - Microsoft Teams
///   - Tencent Meeting / 腾讯会议
///   - Cisco Webex
enum MeetingURLExtractor {

    /// Regex patterns ordered by specificity. First match wins.
    private static let patterns: [String] = [
        // Lark / Feishu — both the deep-link scheme and the http variants
        #"https?://[^\s)]*\.?lark\.cn/[^\s)]+"#,
        #"https?://[^\s)]*\.?feishu\.cn/[^\s)]+"#,
        #"lark://meetings/[^\s)]+"#,
        #"feishu://meetings/[^\s)]+"#,
        // Zoom
        #"https?://[a-zA-Z0-9-]*\.?zoom\.us/(?:j|s|my|w)/[^\s)]+"#,
        // Google Meet
        #"https?://meet\.google\.com/[a-z0-9-]+"#,
        // Microsoft Teams
        #"https?://teams\.microsoft\.com/l/meetup-join/[^\s)]+"#,
        #"msteams:/l/meetup-join/[^\s)]+"#,
        // Tencent Meeting
        #"https?://meeting\.tencent\.com/[^\s)]+"#,
        #"https?://[a-zA-Z0-9-]*\.tencentmeeting\.com/[^\s)]+"#,
        #"wemeet://[^\s)]+"#,
        // Webex
        #"https?://[a-zA-Z0-9-]*\.webex\.com/(?:meet|join)/[^\s)]+"#,
    ]

    static func firstJoinURL(location: String?, notes: String?, url: String?) -> URL? {
        let haystacks = [url, location, notes].compactMap { $0 }
        for haystack in haystacks {
            for pattern in patterns {
                if let range = haystack.range(of: pattern, options: .regularExpression) {
                    let raw = String(haystack[range])
                    if let u = URL(string: raw) { return u }
                }
            }
        }
        return nil
    }

    /// Best-effort display label for a join URL (e.g., "Zoom", "Google Meet").
    static func providerLabel(for url: URL) -> String {
        let s = url.absoluteString.lowercased()
        if s.contains("lark") { return "Lark" }
        if s.contains("feishu") { return "飞书" }
        if s.contains("zoom") { return "Zoom" }
        if s.contains("meet.google.com") { return "Google Meet" }
        if s.contains("teams.microsoft.com") || s.contains("msteams") { return "Teams" }
        if s.contains("tencent") || s.contains("wemeet") { return "腾讯会议" }
        if s.contains("webex") { return "Webex" }
        return "Meeting"
    }
}
