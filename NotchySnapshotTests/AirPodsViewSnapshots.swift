import Testing
import SwiftUI
import SnapshotTesting
import AppKit
@testable import Notchy

@MainActor
struct AirPodsViewSnapshots {
    @Test func fullBattery() {
        let vm = BTDeviceVM(
            name: "Zhangjie's AirPods Pro", model: "2nd Generation",
            battery: BatteryReading(left: 78, right: 82, caseLevel: 95)
        )
        let v = AirPodsView(vm: vm).frame(width: 540, height: 180).background(.black)
        assertSnapshot(of: host(v, width: 540, height: 180), as: .image, named: "full")
    }

    @Test func missingValues() {
        let vm = BTDeviceVM(
            name: "AirPods Max", model: "1st Generation",
            battery: BatteryReading(left: 30, right: nil, caseLevel: nil)
        )
        let v = AirPodsView(vm: vm).frame(width: 540, height: 180).background(.black)
        assertSnapshot(of: host(v, width: 540, height: 180), as: .image, named: "missing")
    }

    private func host<V: View>(_ view: V, width: CGFloat, height: CGFloat) -> NSView {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        host.layoutSubtreeIfNeeded()
        return host
    }
}
