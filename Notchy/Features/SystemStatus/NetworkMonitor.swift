import Foundation
import Darwin

/// Samples per-interface byte counts every 2s via `getifaddrs` + `if_data64`
/// and pushes bytes/sec rates into SystemStatusFeature.
///
/// Aggregates across all `en0..N` (Wi-Fi + Ethernet + Thunderbolt) and any
/// `utun*` (VPN) interfaces. Excludes `lo0` loopback.
@MainActor
final class NetworkMonitor {

    private let status: SystemStatusFeature
    private var timer: Timer?
    private var prevIn: UInt64 = 0
    private var prevOut: UInt64 = 0
    private var prevTime: Date = .distantPast

    init(status: SystemStatusFeature) {
        self.status = status
    }

    func start() {
        let initial = readTotals()
        prevIn = initial.bytesIn
        prevOut = initial.bytesOut
        prevTime = Date()
        let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let now = readTotals()
        let elapsed = Date().timeIntervalSince(prevTime)
        guard elapsed > 0 else { return }
        // Handle UInt64 wraparound (interface restarts reset counters).
        let deltaIn  = now.bytesIn  >= prevIn  ? Double(now.bytesIn  - prevIn)  : 0
        let deltaOut = now.bytesOut >= prevOut ? Double(now.bytesOut - prevOut) : 0
        status.networkDown = deltaIn  / elapsed
        status.networkUp   = deltaOut / elapsed
        prevIn = now.bytesIn
        prevOut = now.bytesOut
        prevTime = Date()
    }

    private func readTotals() -> (bytesIn: UInt64, bytesOut: UInt64) {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return (0, 0) }
        defer { freeifaddrs(addrs) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let curr = ptr {
            defer { ptr = curr.pointee.ifa_next }
            let name = String(cString: curr.pointee.ifa_name)
            // Exclude loopback; include en*, utun* (VPN), and bridge*.
            guard !name.hasPrefix("lo"),
                  name.hasPrefix("en") || name.hasPrefix("utun") || name.hasPrefix("bridge")
            else { continue }
            guard let addr = curr.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            guard let data = curr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }
            totalIn += UInt64(data.pointee.ifi_ibytes)
            totalOut += UInt64(data.pointee.ifi_obytes)
        }
        return (totalIn, totalOut)
    }
}
