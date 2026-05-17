import Foundation
import IOKit.ps
import Darwin

struct SystemSnapshot: Equatable, Sendable {
    var cpuPercent: Int
    var batteryPercent: Int?
    var isCharging: Bool
}

actor SystemMonitorBridge {
    private var previousCPU: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

    func snapshot() -> SystemSnapshot {
        let cpu = readCPUPercent()
        let (battery, charging) = readBattery()
        return SystemSnapshot(cpuPercent: cpu, batteryPercent: battery, isCharging: charging)
    }

    private func readCPUPercent() -> Int {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let user = UInt32(info.cpu_ticks.0)
        let system = UInt32(info.cpu_ticks.1)
        let idle = UInt32(info.cpu_ticks.2)
        let nice = UInt32(info.cpu_ticks.3)

        defer { previousCPU = (user, system, idle, nice) }

        guard let prev = previousCPU else { return 0 }
        let usedDelta = (user &- prev.user) &+ (system &- prev.system) &+ (nice &- prev.nice)
        let idleDelta = idle &- prev.idle
        let totalDelta = usedDelta &+ idleDelta
        guard totalDelta > 0 else { return 0 }
        let pct = Int((Double(usedDelta) / Double(totalDelta)) * 100)
        return min(100, max(0, pct))
    }

    private func readBattery() -> (Int?, Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as? [CFTypeRef] else {
            return (nil, false)
        }
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] else { continue }
            let pct = desc[kIOPSCurrentCapacityKey as String] as? Int
            let state = desc[kIOPSPowerSourceStateKey as String] as? String
            let charging = state == kIOPSACPowerValue
            return (pct, charging)
        }
        return (nil, false)
    }
}
