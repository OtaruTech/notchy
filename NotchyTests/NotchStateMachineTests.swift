import Testing
@testable import Notchy

@MainActor
struct NotchStateMachineTests {

    @Test func startsIdle() {
        let sm = NotchStateMachine()
        #expect(sm.state == .idle)
    }

    @Test func hoverWithNoMediaExpandsToDashboard() {
        let sm = NotchStateMachine()
        sm.send(.hoverEntered)
        #expect(sm.state == .dashboard)
    }

    @Test func hoverWithMediaExpandsToMedia() {
        let sm = NotchStateMachine()
        sm.send(.mediaAvailabilityChanged(true))
        sm.send(.hoverEntered)
        #expect(sm.state == .media)
    }

    @Test func hoverExitedFromMediaCollapsesToHint() {
        let sm = NotchStateMachine()
        sm.send(.mediaAvailabilityChanged(true))
        sm.send(.hoverEntered)
        sm.send(.hoverExited)
        #expect(sm.state == .hint)
    }

    @Test func hoverExitedFromDashboardCollapsesToIdle() {
        let sm = NotchStateMachine()
        sm.send(.hoverEntered)
        #expect(sm.state == .dashboard)
        sm.send(.hoverExited)
        #expect(sm.state == .idle)
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

    @Test func timerStartedExpandsToTimer() {
        let sm = NotchStateMachine()
        sm.send(.timerStarted)
        #expect(sm.state == .timer)
    }

    @Test func timerCompletedReturnsToIdle() {
        let sm = NotchStateMachine()
        sm.send(.timerStarted)
        sm.send(.timerCompleted)
        #expect(sm.state == .idle)
    }

    @Test func tabSwitchedChangesStateOnlyIfExpanded() {
        let sm = NotchStateMachine()
        sm.send(.tabSwitchedTo(.calendar))
        #expect(sm.state == .idle)
        sm.send(.mediaAvailabilityChanged(true))
        sm.send(.hoverEntered)
        #expect(sm.state == .media)
        sm.send(.tabSwitchedTo(.calendar))
        #expect(sm.state == .calendar)
    }

    @Test func stickyTabRestoredOnNextHover() {
        let sm = NotchStateMachine()
        sm.send(.mediaAvailabilityChanged(true))
        sm.send(.hoverEntered)
        #expect(sm.state == .media)
        sm.send(.tabSwitchedTo(.dashboard))
        #expect(sm.state == .dashboard)
        sm.send(.hoverExited)
        #expect(sm.state == .hint)
        sm.send(.hoverEntered)
        #expect(sm.state == .dashboard)  // sticky restored, not jumping back to media
    }
}
