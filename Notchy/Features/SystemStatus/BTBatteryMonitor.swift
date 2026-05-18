import Foundation
import IOBluetooth

/// Polls IOBluetooth for the battery level of every connected paired device.
/// Pushes the list into SystemStatusFeature.btDevices.
///
/// Cadence: 30s (battery levels change slowly), plus immediate refresh on
/// connect/disconnect notifications.
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
        let raw = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        let connected = raw.filter { $0.isConnected() }
        let snapshots = connected.map { snapshot(for: $0) }
        status.btDevices = snapshots
    }

    private func snapshot(for device: IOBluetoothDevice) -> SystemStatusFeature.BTDeviceBattery {
        let address = device.addressString ?? device.name ?? UUID().uuidString
        let name = device.name ?? "Bluetooth Device"
        let kind = classify(name: name)
        let battery = readBattery(address: address)
        return SystemStatusFeature.BTDeviceBattery(
            id: address,
            name: name,
            kind: kind,
            main: battery.main,
            left: battery.left,
            right: battery.right,
            caseLevel: battery.caseLevel
        )
    }

    private func classify(name: String) -> SystemStatusFeature.BTDeviceBattery.Kind {
        let n = name.lowercased()
        if n.contains("airpod") { return .airpods }
        if n.contains("mouse") { return .mouse }
        if n.contains("keyboard") { return .keyboard }
        if n.contains("watch") { return .watch }
        if n.contains("beats") || n.contains("headphone") || n.contains("耳机") { return .headphones }
        return .generic
    }

    // MARK: IORegistry battery reading

    private struct Battery { let main: Int?; let left: Int?; let right: Int?; let caseLevel: Int? }

    private func readBattery(address: String) -> Battery {
        // Walk the BluetoothHCIControllerService IORegistry for entries
        // matching the device address; read BatteryPercent / BatteryPercentLeft
        // / BatteryPercentRight / BatteryPercentCase.
        let normalised = address.replacingOccurrences(of: ":", with: "-").lowercased()
        var iterator: io_iterator_t = 0
        let match = IOServiceMatching("IOBluetoothDevice")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else {
            return Battery(main: nil, left: nil, right: nil, caseLevel: nil)
        }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            let addrProp = IORegistryEntryCreateCFProperty(service, "DeviceAddress" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
            if let addr = addrProp?.lowercased().replacingOccurrences(of: ":", with: "-"),
               addr == normalised {
                return Battery(
                    main: intProperty(service, "BatteryPercent"),
                    left: intProperty(service, "BatteryPercentLeft"),
                    right: intProperty(service, "BatteryPercentRight"),
                    caseLevel: intProperty(service, "BatteryPercentCase")
                )
            }
        }
        return Battery(main: nil, left: nil, right: nil, caseLevel: nil)
    }

    private func intProperty(_ service: io_object_t, _ key: String) -> Int? {
        guard let v = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber else {
            return nil
        }
        return v.intValue
    }
}
