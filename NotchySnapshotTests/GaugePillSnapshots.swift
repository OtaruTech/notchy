import Testing
import SwiftUI
import SnapshotTesting
@testable import Notchy

@MainActor
struct GaugePillSnapshots {
    @Test func normal() {
        let snap = SystemSnapshot(cpuPercent: 24, batteryPercent: 78, isCharging: false)
        let v = GaugePill(snapshot: snap).padding(8).background(.black)
        assertSnapshot(of: snapshotHost(v, width: 160, height: 32), as: .image, named: "normal")
    }

    @Test func lowBattery() {
        let snap = SystemSnapshot(cpuPercent: 12, batteryPercent: 8, isCharging: false)
        let v = GaugePill(snapshot: snap).padding(8).background(.black)
        assertSnapshot(of: snapshotHost(v, width: 160, height: 32), as: .image, named: "low-battery")
    }

    @Test func charging() {
        let snap = SystemSnapshot(cpuPercent: 45, batteryPercent: 60, isCharging: true)
        let v = GaugePill(snapshot: snap).padding(8).background(.black)
        assertSnapshot(of: snapshotHost(v, width: 160, height: 32), as: .image, named: "charging")
    }
}
