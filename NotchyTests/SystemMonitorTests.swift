import Testing
@testable import Notchy

@MainActor
struct SystemMonitorTests {
    @Test func snapshotDefaults() {
        let bridge = SystemMonitorBridge()
        let f = SystemMonitorFeature(bridge: bridge)
        #expect(f.snapshot.cpuPercent == 0)
        #expect(f.snapshot.batteryPercent == nil)
        #expect(f.snapshot.isCharging == false)
    }
}
