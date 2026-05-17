import Testing
@testable import Notchy

@MainActor
struct CalendarFeatureTests {
    @Test func eventVMConstructsManually() {
        let vm = EventVM(
            id: "x", title: "Standup",
            startTime: "10:00 AM", endTime: "10:30 AM",
            calendarColorRGBA: [0, 1, 0, 1],
            isInProgress: false
        )
        #expect(vm.title == "Standup")
        #expect(vm.startTime == "10:00 AM")
    }

    @Test func eventVMReconstructsCGColor() {
        let vm = EventVM(
            id: "x", title: "T",
            startTime: "10:00 AM", endTime: "10:30 AM",
            calendarColorRGBA: [0.2, 0.4, 0.8, 1],
            isInProgress: true
        )
        let color = vm.calendarColor
        #expect(color.components?[0] == 0.2)
        #expect(color.components?[2] == 0.8)
    }

    @Test func featureStartsEmpty() {
        let bridge = EventKitBridge()
        let sm = NotchStateMachine()
        let f = CalendarFeature(bridge: bridge, stateMachine: sm)
        #expect(f.events.isEmpty)
        #expect(f.permissionState == .denied)
    }
}
