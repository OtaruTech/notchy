import Testing
import SwiftUI
import SnapshotTesting
@testable import Notchy

@MainActor
struct TimerViewSnapshots {
    @Test func idle() {
        let v = TimerView(state: .idle, progress: 0)
            .frame(width: 540, height: 180)
            .background(.black)
        assertSnapshot(of: snapshotHost(v, width: 540, height: 180), as: .image, named: "idle")
    }

    @Test func runningHalfway() {
        let v = TimerView(state: .running(remaining: 750, total: 1500), progress: 0.5)
            .frame(width: 540, height: 180)
            .background(.black)
        assertSnapshot(of: snapshotHost(v, width: 540, height: 180), as: .image, named: "running")
    }
}
