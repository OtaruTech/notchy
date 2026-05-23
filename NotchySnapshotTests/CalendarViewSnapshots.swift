import Testing
import Foundation
import SwiftUI
import SnapshotTesting
@testable import Notchy

@MainActor
struct CalendarViewSnapshots {
    @Test func twoEvents() {
        let now = Date()
        let evs = [
            EventVM(id: "a", title: "Standup", startTime: "10:00 AM", endTime: "10:30 AM",
                    startDate: now, endDate: now.addingTimeInterval(1800),
                    calendarColorRGBA: [0.2, 0.7, 1, 1], isInProgress: true, joinURL: nil),
            EventVM(id: "b", title: "Design review with team", startTime: "2:00 PM", endTime: "3:00 PM",
                    startDate: now.addingTimeInterval(14400), endDate: now.addingTimeInterval(18000),
                    calendarColorRGBA: [1, 0.4, 0.3, 1], isInProgress: false, joinURL: nil)
        ]
        let v = CalendarView(events: evs, onEventTap: { _ in })
            .frame(width: 540, height: 180)
            .background(.black)
        assertSnapshot(of: snapshotHost(v, width: 540, height: 180), as: .image, named: "two-events")
    }

    @Test func empty() {
        let v = CalendarView(events: [], onEventTap: { _ in })
            .frame(width: 540, height: 180)
            .background(.black)
        assertSnapshot(of: snapshotHost(v, width: 540, height: 180), as: .image, named: "empty")
    }
}
