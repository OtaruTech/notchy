import EventKit
import Foundation

struct EventVM: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let startTime: String   // formatted "10:30 AM"
    let endTime: String     // formatted "11:00 AM"
    let calendarColorRGBA: [Double]  // [r,g,b,a] for Sendable; reconstruct CGColor in view
    let isInProgress: Bool

    static func from(_ event: EKEvent) -> EventVM {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        let now = Date()
        let cg = event.calendar?.cgColor ?? CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let rgba: [Double] = (cg.components?.map { Double($0) }) ?? [0.5, 0.5, 0.5, 1]
        return EventVM(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "Untitled",
            startTime: df.string(from: event.startDate),
            endTime: df.string(from: event.endDate),
            calendarColorRGBA: rgba.count >= 4 ? rgba : [0.5, 0.5, 0.5, 1],
            isInProgress: event.startDate <= now && event.endDate >= now
        )
    }

    /// Reconstruct CGColor for view consumption.
    var calendarColor: CGColor {
        let c = calendarColorRGBA
        return CGColor(red: c[0], green: c[1], blue: c[2], alpha: c.count >= 4 ? c[3] : 1)
    }
}
