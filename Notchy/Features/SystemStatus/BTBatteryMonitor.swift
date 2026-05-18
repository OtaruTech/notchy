import Foundation
import IOBluetooth

fileprivate func _btLog(_ msg: String) {
    guard UserDefaults.standard.bool(forKey: "notchy.debugLogging") else { return }
    let line = "\(Date()) [Notchy.BT] \(msg)\n"
    let path = "/tmp/notchy.log"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: path),
           let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            h.seekToEndOfFile(); try? h.write(contentsOf: data); try? h.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

/// Polls `system_profiler SPBluetoothDataType -json` every 30 s for the
/// battery level of every currently-connected paired device.
///
/// `system_profiler` is slower than IORegistry (~300 ms subprocess) but
/// reliably exposes the `device_batteryLevelMain` / `device_batteryLevelLeft`
/// / `device_batteryLevelRight` / `device_batteryLevelCase` keys for both
/// Apple devices (AirPods, Magic Mouse, Magic Keyboard, Watch) AND
/// third-party Bluetooth peripherals.
///
/// Cadence: 30 s timer + immediate refresh on connect/disconnect.
@MainActor
final class BTBatteryMonitor {

    private let status: SystemStatusFeature
    private var timer: Timer?
    private var connectToken: NSObjectProtocol?
    private var disconnectToken: NSObjectProtocol?

    init(status: SystemStatusFeature) {
        self.status = status
    }

    func start() {
        refresh()
        let t = Timer(timeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        let center = NotificationCenter.default
        connectToken = center.addObserver(
            forName: NSNotification.Name("IOBluetoothDeviceDidConnect"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        disconnectToken = center.addObserver(
            forName: NSNotification.Name("IOBluetoothDeviceDidDisconnect"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let t = connectToken { NotificationCenter.default.removeObserver(t) }
        if let t = disconnectToken { NotificationCenter.default.removeObserver(t) }
    }

    // MARK: refresh

    private func refresh() {
        Task.detached(priority: .utility) {
            let devices = Self.querySystemProfiler()
            await MainActor.run { [weak self] in
                self?.status.btDevices = devices
                _btLog("refresh → \(devices.count) device(s) [\(devices.map { $0.name }.joined(separator: ", "))]")
            }
        }
    }

    // MARK: system_profiler

    nonisolated private static func querySystemProfiler() -> [SystemStatusFeature.BTDeviceBattery] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let array = json["SPBluetoothDataType"] as? [[String: Any]]
        else { return [] }

        var devices: [SystemStatusFeature.BTDeviceBattery] = []
        for top in array {
            // Connected devices live under either "device_connected" (Big Sur+)
            // or "device_paired" with a connected flag (older).
            let connected = (top["device_connected"] as? [Any]) ?? []
            for entry in connected {
                guard let entryDict = entry as? [String: Any] else { continue }
                for (name, info) in entryDict {
                    guard let dict = info as? [String: Any] else { continue }
                    devices.append(parse(name: name, info: dict))
                }
            }
        }
        return devices
    }

    nonisolated private static func parse(name: String, info: [String: Any]) -> SystemStatusFeature.BTDeviceBattery {
        let main  = pct(info["device_batteryLevelMain"]) ?? pct(info["device_batteryLevel"]) ?? pct(info["device_batteryPercent"])
        let left  = pct(info["device_batteryLevelLeft"])
        let right = pct(info["device_batteryLevelRight"])
        let case_ = pct(info["device_batteryLevelCase"])
        let address = (info["device_address"] as? String) ?? name
        let minor = (info["device_minorType"] as? String)?.lowercased() ?? ""
        let kind = classify(name: name.lowercased(), minor: minor)
        return SystemStatusFeature.BTDeviceBattery(
            id: address,
            name: name,
            kind: kind,
            main: main,
            left: left,
            right: right,
            caseLevel: case_
        )
    }

    /// Parses "64%" → 64. Handles bare integers + strings without %.
    nonisolated private static func pct(_ raw: Any?) -> Int? {
        if let n = raw as? NSNumber { return n.intValue }
        if let s = raw as? String {
            let digits = s.filter { $0.isNumber }
            return Int(digits)
        }
        return nil
    }

    nonisolated private static func classify(name: String, minor: String) -> SystemStatusFeature.BTDeviceBattery.Kind {
        let combined = "\(name) \(minor)"
        if combined.contains("airpod") { return .airpods }
        if combined.contains("mouse") { return .mouse }
        if combined.contains("keyboard") { return .keyboard }
        if combined.contains("watch") { return .watch }
        if combined.contains("beats") || combined.contains("headphone") || combined.contains("耳机") { return .headphones }
        return .generic
    }
}
