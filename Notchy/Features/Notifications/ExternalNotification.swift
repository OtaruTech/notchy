import Foundation

/// One notification dropped into Notchy's inbox by an external producer
/// (Claude Code hook, custom scripts, etc.). Serialised as JSON; see the
/// hook documentation for the producer schema.
///
/// File location: `~/Library/Application Support/tech.otaru.Notchy/inbox/*.json`
/// The watcher consumes (reads + deletes) files atomically.
struct ExternalNotification: Codable, Equatable, Identifiable, Sendable {

    /// Stable identity — generated client-side if the producer omits it.
    let id: String

    /// Free-form source tag — surfaces in the pill icon / accent color.
    /// Known values: "claude-code", "claude-code-mascot", "custom".
    let source: String

    /// Semantic kind — drives color + sticky default. Unknown values render
    /// as `.info`.
    let kind: Kind

    let title: String
    let body: String

    /// Originating directory (cwd). When non-nil, clicking the pill activates
    /// the terminal app and (best-effort) focuses the window whose title
    /// contains this path.
    let cwd: String?

    /// Optional Claude Code session id. Stored for telemetry/observability;
    /// not surfaced in the UI.
    let sessionID: String?

    /// Seconds before auto-dismiss. Ignored when `sticky == true`.
    /// Default 8s for info, 30s for input-needed.
    let ttlSeconds: Double

    /// When true, pill stays until the user clicks it.
    let sticky: Bool

    /// When the file landed in the inbox (best-effort; reflects mtime).
    let receivedAt: Date

    enum Kind: String, Codable, Sendable {
        case info             // generic alert
        case inputNeeded      // user must respond — sticky by default
        case toolApproval     // a tool wants permission
        case complete         // a task finished
        case error            // something failed

        var defaultSticky: Bool {
            switch self {
            case .inputNeeded, .toolApproval, .error: return true
            case .info, .complete: return false
            }
        }

        var defaultTTL: Double {
            switch self {
            case .info: return 8
            case .complete: return 6
            case .inputNeeded, .toolApproval: return 30
            case .error: return 15
            }
        }
    }

    // MARK: decoding from inbox JSON

    enum DecodeError: Error {
        case malformedJSON
    }

    /// Build from raw JSON dict. Fills in defaults so producers can omit most
    /// fields. Throws only when title is missing (the minimum signal needed).
    static func decode(from dict: [String: Any], receivedAt: Date) throws -> ExternalNotification {
        guard let title = dict["title"] as? String, !title.isEmpty else {
            throw DecodeError.malformedJSON
        }
        let kindRaw = dict["kind"] as? String ?? "info"
        let kind = Kind(rawValue: kindRaw) ?? .info
        let id = (dict["id"] as? String) ?? UUID().uuidString
        let source = (dict["source"] as? String) ?? "external"
        let body = (dict["body"] as? String) ?? ""
        let cwd = dict["cwd"] as? String
        let sessionID = dict["session_id"] as? String
        let ttl = (dict["ttl_seconds"] as? Double) ?? kind.defaultTTL
        let sticky = (dict["sticky"] as? Bool) ?? kind.defaultSticky
        return ExternalNotification(
            id: id, source: source, kind: kind,
            title: title, body: body,
            cwd: cwd, sessionID: sessionID,
            ttlSeconds: ttl, sticky: sticky,
            receivedAt: receivedAt
        )
    }
}
