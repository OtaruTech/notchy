import Foundation

/// Append-only JSON log of completed Pomodoro sessions. Persisted at
/// `~/Library/Application Support/tech.otaru.Notchy/pomodoro-log.json`.
/// Capped at 1000 entries — older rows fall off the front.
struct PomodoroEntry: Codable, Equatable, Sendable {
    let completedAt: Date
    let durationMin: Int
}

@MainActor
final class PomodoroLog {

    private static let maxEntries = 1000
    private let url: URL
    private(set) var entries: [PomodoroEntry] = []

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("tech.otaru.Notchy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent("pomodoro-log.json")
        load()
    }

    func append(durationMin: Int, at date: Date = Date()) {
        let entry = PomodoroEntry(completedAt: date, durationMin: durationMin)
        entries.append(entry)
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
        save()
    }

    func clear() {
        entries.removeAll()
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: stats

    /// Number of sessions completed on the same calendar day as `date`.
    func count(on date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return entries.lazy.filter { $0.completedAt >= start && $0.completedAt < end }.count
    }

    /// Total minutes of focus on the same calendar day.
    func minutes(on date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return entries.lazy
            .filter { $0.completedAt >= start && $0.completedAt < end }
            .reduce(0) { $0 + $1.durationMin }
    }

    /// Number of consecutive days (ending today) with ≥1 session.
    func streak(calendar: Calendar = .current) -> Int {
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        while count(on: day, calendar: calendar) > 0 {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    /// Counts for the last `days` calendar days, oldest first.
    /// Used by the heat-map dots.
    func dailyCounts(lastDays: Int, calendar: Calendar = .current) -> [Int] {
        var out: [Int] = []
        let today = calendar.startOfDay(for: Date())
        for offset in (0..<lastDays).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                out.append(0); continue
            }
            out.append(count(on: day, calendar: calendar))
        }
        return out
    }

    // MARK: I/O

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        guard let decoded = try? JSONDecoder().decode([PomodoroEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url)
    }
}
