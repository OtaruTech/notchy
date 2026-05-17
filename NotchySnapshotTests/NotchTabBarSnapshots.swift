import Testing
import SwiftUI
import SnapshotTesting
@testable import Notchy

@MainActor
struct NotchTabBarSnapshots {
    @Test func threeTabsMediaActive() {
        let v = NotchTabBar(
            availableTabs: [.media, .drop, .calendar],
            active: .media,
            onSelect: { _ in }
        )
        .frame(width: 220, height: 40)
        .background(.black)
        assertSnapshot(of: snapshotHost(v, width: 220, height: 40), as: .image, named: "three-media")
    }

    @Test func fiveTabsCalendarActive() {
        let v = NotchTabBar(
            availableTabs: [.media, .drop, .airpods, .calendar, .timer],
            active: .calendar,
            onSelect: { _ in }
        )
        .frame(width: 320, height: 40)
        .background(.black)
        assertSnapshot(of: snapshotHost(v, width: 320, height: 40), as: .image, named: "five-calendar")
    }
}
