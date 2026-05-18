import Foundation
import IOKit.ps

/// Polls IOPS (IO Power Sources) for the current charging state + adapter
/// wattage. Pushes updates into a SystemStatusFeature.
///
/// Polling interval adapts: 1 s while charging (wattage / charge % update
/// frequently), 5 s on battery (state changes are rare).
@MainActor
final class PowerMonitor {

    private let status: SystemStatusFeature
    private var timer: Timer?

    init(status: SystemStatusFeature) {
        self.status = status
    }

    func start() {
        tick()
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval: TimeInterval = status.isCharging ? 1.0 : 5.0
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let snapshot = read()
        let chargedStateFlipped = snapshot.isCharging != status.isCharging
        status.isCharging = snapshot.isCharging
        status.chargingWatts = snapshot.watts

        // If we crossed the charging boundary, adjust polling frequency.
        if chargedStateFlipped { scheduleTimer() }
    }

    // MARK: read

    private struct Snapshot {
        let isCharging: Bool
        let watts: Int?
    }

    private func read() -> Snapshot {
        guard let blob = IOPSCopyPowerSourcesInfo() else {
            return Snapshot(isCharging: false, watts: nil)
        }
        let info = blob.takeRetainedValue()
        guard let sources = IOPSCopyPowerSourcesList(info) else {
            return Snapshot(isCharging: false, watts: nil)
        }
        let list = sources.takeRetainedValue() as Array

        var isCharging = false
        var watts: Int? = nil

        for source in list {
            guard let dict = IOPSGetPowerSourceDescription(info, source).takeUnretainedValue() as? [String: Any] else { continue }
            // Charging flag — true while plugged in AND still filling battery.
            if let charging = dict[kIOPSIsChargingKey as String] as? Bool, charging {
                isCharging = true
            }
            // "AC Power" state = plugged in (even at 100%).
            if let state = dict[kIOPSPowerSourceStateKey as String] as? String,
               state == kIOPSACPowerValue {
                // Even at 100%, we want to show the wattage badge.
                isCharging = isCharging || true
            }
            // Adapter wattage lives in a nested dict on M-series Macs.
            if let adapter = dict["AdapterDetails"] as? [String: Any] {
                if let w = adapter["Watts"] as? Int {
                    watts = w
                } else if let w = adapter["Watts"] as? NSNumber {
                    watts = w.intValue
                }
            }
            if watts == nil, let w = dict["Current Power"] as? Int {
                watts = w
            }
        }

        // Don't expose `watts` if we're on battery — only meaningful while
        // plugged in.
        if !isCharging { watts = nil }
        return Snapshot(isCharging: isCharging, watts: watts)
    }
}
