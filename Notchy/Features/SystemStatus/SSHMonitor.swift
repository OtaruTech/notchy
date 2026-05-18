import Foundation

/// Periodically runs `ps -axo pid,etime,command` and finds active `ssh` /
/// `mosh` processes. Reports their target hostnames + elapsed time +
/// whether the host matches a "dangerous" pattern (prod / production / live).
///
/// Cadence: 30 s. Listing process snapshots is cheap (single subprocess) so
/// no need for kqueue here.
@MainActor
final class SSHMonitor {

    private let status: SystemStatusFeature
    private var timer: Timer?

    /// Default regex matched against extracted hostnames to flag the row red.
    /// Override via `notchy.indicatorSSHDangerPattern` UserDefault.
    nonisolated static let defaultDangerPattern = "prod|production|live"

    init(status: SystemStatusFeature) {
        self.status = status
    }

    func start() {
        refresh()
        let t = Timer(timeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        Task.detached(priority: .utility) {
            let sessions = Self.querySessions()
            await MainActor.run { [weak self] in self?.status.sshSessions = sessions }
        }
    }

    nonisolated private static func querySessions() -> [SystemStatusFeature.SSHSession] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "pid,etime,command"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        let dangerPattern = (UserDefaults.standard.string(forKey: "notchy.indicatorSSHDangerPattern")
                             ?? defaultDangerPattern)
        let dangerRegex = try? NSRegularExpression(pattern: dangerPattern, options: [.caseInsensitive])

        var sessions: [SystemStatusFeature.SSHSession] = []
        let lines = text.split(whereSeparator: { $0 == "\n" })
        for line in lines.dropFirst() {  // skip header
            let cols = line.split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" })
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard cols.count >= 3,
                  let pid = Int32(cols[0])
            else { continue }
            let etime = cols[1]
            let command = cols[2]
            guard let host = extractSSHHost(command: command) else { continue }
            // Skip ssh helper subprocesses (sshd, ssh-agent, etc.) — only client.
            if command.contains("sshd") || command.contains("ssh-agent") || command.contains("ssh-add") {
                continue
            }
            let isDangerous = dangerRegex?.firstMatch(
                in: host,
                range: NSRange(host.startIndex..., in: host)
            ) != nil
            sessions.append(.init(
                id: pid,
                host: host,
                elapsedSeconds: parseElapsed(etime),
                isDangerous: isDangerous
            ))
        }
        return sessions
    }

    /// Extract `user@host` or bare `host.tld` from a command line like
    /// `ssh -p 2222 user@example.com -L 9000:localhost:9000`.
    nonisolated private static func extractSSHHost(command: String) -> String? {
        // Must start with ssh or mosh as the executable (full path or bare).
        let lower = command.lowercased()
        guard lower.contains("/ssh ") || lower.hasPrefix("ssh ") ||
              lower.contains("/mosh ") || lower.hasPrefix("mosh ")
        else { return nil }

        // Strip flags. Walk argv-style. We accept the first non-flag token
        // that matches `user@host` or `host.tld`.
        let tokens = command.split(whereSeparator: { $0 == " " }).map(String.init)
        var index = 0
        // Skip executable.
        while index < tokens.count {
            let t = tokens[index]
            if t == "ssh" || t.hasSuffix("/ssh") || t == "mosh" || t.hasSuffix("/mosh") {
                index += 1
                break
            }
            index += 1
        }
        // Flag-skip: -p / -i / -L / -R / -D / -o consume the next arg, single-letter
        // flags without arg just skip themselves.
        let twoArgFlags: Set<String> = ["-p", "-i", "-L", "-R", "-D", "-o", "-F", "-l"]
        while index < tokens.count {
            let t = tokens[index]
            if t.hasPrefix("-") {
                if twoArgFlags.contains(t) { index += 2 } else { index += 1 }
                continue
            }
            // First non-flag = the host target.
            if t.contains("@") { return t }
            if t.contains(".") { return t }
            return t
        }
        return nil
    }

    /// Parses `ps`'s `etime` format: `[[dd-]hh:]mm:ss`. Returns seconds.
    nonisolated private static func parseElapsed(_ s: String) -> Int {
        var rest = s
        var days = 0
        if let dashIdx = rest.firstIndex(of: "-") {
            days = Int(rest[..<dashIdx]) ?? 0
            rest = String(rest[rest.index(after: dashIdx)...])
        }
        let parts = rest.split(separator: ":").map(String.init).compactMap(Int.init)
        switch parts.count {
        case 3:  // hh:mm:ss
            return days * 86_400 + parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2:  // mm:ss
            return days * 86_400 + parts[0] * 60 + parts[1]
        default:
            return 0
        }
    }
}
