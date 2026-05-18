import EventKit
import Foundation

struct EventVM: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let startTime: String   // formatted "10:30 AM"
    let endTime: String     // formatted "11:00 AM"
    let startDate: Date     // raw for countdown math
    let endDate: Date
    let calendarColorRGBA: [Double]
    let isInProgress: Bool
    /// First detected meeting URL (Zoom / Google Meet / Lark / Feishu / Teams /
    /// Tencent Meeting / Webex) found in event.location or event.notes.
    /// nil ⇒ no joinable meeting URL.
    let joinURL: URL?

    static func from(_ event: EKEvent) -> EventVM {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        let now = Date()
        let cg = event.calendar?.cgColor ?? CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let rgba: [Double] = (cg.components?.map { Double($0) }) ?? [0.5, 0.5, 0.5, 1]
        let joinURL = MeetingURLExtractor.firstJoinURL(
            location: event.location,
            notes: event.notes,
            url: event.url?.absoluteString
        )
        return EventVM(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "Untitled",
            startTime: df.string(from: event.startDate),
            endTime: df.string(from: event.endDate),
            startDate: event.startDate,
            endDate: event.endDate,
            calendarColorRGBA: rgba.count >= 4 ? rgba : [0.5, 0.5, 0.5, 1],
            isInProgress: event.startDate <= now && event.endDate >= now,
            joinURL: joinURL
        )
    }

    var calendarColor: CGColor {
        let c = calendarColorRGBA
        return CGColor(red: c[0], green: c[1], blue: c[2], alpha: c.count >= 4 ? c[3] : 1)
    }

    /// Seconds until the event starts. Negative if already started.
    func secondsUntilStart(now: Date = Date()) -> TimeInterval {
        startDate.timeIntervalSince(now)
    }

    /// True ⇒ within 5 minutes of start OR currently in progress.
    func isJoinable(now: Date = Date()) -> Bool {
        let secs = secondsUntilStart(now: now)
        return joinURL != nil && (secs <= 300 && now <= endDate)
    }
}
