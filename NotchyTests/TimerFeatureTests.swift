import Testing
@testable import Notchy

@MainActor
struct TimerFeatureTests {
    @Test func startsIdle() {
        let f = TimerFeature(stateMachine: NotchStateMachine())
        #expect(f.state == .idle)
    }

    @Test func startSetsRunning() {
        let f = TimerFeature(stateMachine: NotchStateMachine())
        f.start(seconds: 60)
        if case .running(let r, let t) = f.state {
            #expect(r == 60); #expect(t == 60)
        } else {
            Issue.record("Expected .running state")
        }
        f.stop()  // cleanup
    }

    @Test func progressZeroOnIdle() {
        let f = TimerFeature(stateMachine: NotchStateMachine())
        #expect(f.progress == 0)
    }

    @Test func pauseAndResumePreservesRemaining() {
        let f = TimerFeature(stateMachine: NotchStateMachine())
        f.start(seconds: 30)
        f.pause()
        if case .paused(let r, _) = f.state {
            #expect(r == 30)
        } else {
            Issue.record("Expected .paused state")
        }
        f.resume()
        if case .running = f.state {} else {
            Issue.record("Expected .running state after resume")
        }
        f.stop()
    }

    @Test func resetReturnsToIdle() {
        let f = TimerFeature(stateMachine: NotchStateMachine())
        f.start(seconds: 30)
        f.reset()
        #expect(f.state == .idle)
    }
}
