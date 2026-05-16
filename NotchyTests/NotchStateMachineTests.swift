import Testing
@testable import Notchy

@MainActor
struct NotchStateMachineTests {

    @Test func startsIdle() {
        let sm = NotchStateMachine()
        #expect(sm.state == .idle)
    }

    @Test func hoverWithNoMediaStaysIdle() {
        let sm = NotchStateMachine()
        sm.send(.hoverEntered)
        #expect(sm.state == .idle)
    }

    @Test func hoverWithMediaExpandsToMedia() {
        let sm = NotchStateMachine()
        sm.send(.mediaAvailabilityChanged(true))
        sm.send(.hoverEntered)
        #expect(sm.state == .media)
    }

    @Test func hoverExitedCollapsesToHintIfMediaActive() {
        let sm = NotchStateMachine()
        sm.send(.mediaAvailabilityChanged(true))
        sm.send(.hoverEntered)
        sm.send(.hoverExited)
        #expect(sm.state == .hint)
    }

    @Test func dragEnteredForcesDropEvenOverMedia() {
        let sm = NotchStateMachine()
        sm.send(.mediaAvailabilityChanged(true))
        sm.send(.hoverEntered)
        sm.send(.dragEntered)
        #expect(sm.state == .drop)
    }

    @Test func airPodsConnectedForcesAirPods() {
        let sm = NotchStateMachine()
        sm.send(.airPodsConnected)
        #expect(sm.state == .airpods)
    }

    @Test func dismissTimerReturnsAirPodsToIdleWhenNoMedia() {
        let sm = NotchStateMachine()
        sm.send(.airPodsConnected)
        sm.send(.dismissTimerFired)
        #expect(sm.state == .idle)
    }

    @Test func dismissTimerReturnsAirPodsToHintWhenMediaActive() {
        let sm = NotchStateMachine()
        sm.send(.mediaAvailabilityChanged(true))
        sm.send(.airPodsConnected)
        sm.send(.dismissTimerFired)
        #expect(sm.state == .hint)
    }

    @Test func escapeAlwaysCollapses() {
        let sm = NotchStateMachine()
        sm.send(.mediaAvailabilityChanged(true))
        sm.send(.hoverEntered)
        sm.send(.escapeKeyPressed)
        #expect(sm.state == .hint)
    }

    @Test func mediaAvailabilityFalseDropsToIdle() {
        let sm = NotchStateMachine()
        sm.send(.mediaAvailabilityChanged(true))
        #expect(sm.state == .hint)
        sm.send(.mediaAvailabilityChanged(false))
        #expect(sm.state == .idle)
    }
}
