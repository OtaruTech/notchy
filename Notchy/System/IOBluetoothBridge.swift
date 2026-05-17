import Foundation
import IOBluetooth
import IOKit

struct BTDevice: Equatable, Sendable {
    let name: String
    let model: String
    let address: String
}

enum BTEvent: Sendable {
    case connected(BTDevice)
    case disconnected(BTDevice)
}

actor IOBluetoothBridge {

    private var continuation: AsyncStream<BTEvent>.Continuation?

    func connectionEvents() -> AsyncStream<BTEvent> {
        AsyncStream { cont in
            self.continuation = cont
            let center = NotificationCenter.default
            nonisolated(unsafe) let connectToken = center.addObserver(
                forName: NSNotification.Name("IOBluetoothDeviceDidConnect"),
                object: nil, queue: .main
            ) { [weak self] note in
                guard let device = note.object as? IOBluetoothDevice else { return }
                let bt = BTDevice(
                    name: device.name ?? "Bluetooth Device",
                    model: "AirPods",
                    address: device.addressString ?? ""
                )
                Task { await self?.yield(.connected(bt)) }
            }
            nonisolated(unsafe) let discToken = center.addObserver(
                forName: NSNotification.Name("IOBluetoothDeviceDidDisconnect"),
                object: nil, queue: .main
            ) { [weak self] note in
                guard let device = note.object as? IOBluetoothDevice else { return }
                let bt = BTDevice(
                    name: device.name ?? "Bluetooth Device",
                    model: "AirPods",
                    address: device.addressString ?? ""
                )
                Task { await self?.yield(.disconnected(bt)) }
            }
            cont.onTermination = { _ in
                center.removeObserver(connectToken)
                center.removeObserver(discToken)
            }
        }
    }

    private func yield(_ event: BTEvent) {
        continuation?.yield(event)
    }

    /// Read battery from IORegistry. Returns nil entries when properties are missing.
    func battery(for address: String) -> BatteryReading {
        let matching = IOServiceMatching("IOBluetoothDevice")
        var iter: io_iterator_t = 0
        IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter)
        defer { IOObjectRelease(iter) }

        var service = IOIteratorNext(iter)
        while service != 0 {
            defer { IOObjectRelease(service) }
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] {
                let addr = dict["BD_ADDR"] as? String
                if addr == address {
                    return BatteryReading.parse(
                        left: dict["BatteryPercentLeft"],
                        right: dict["BatteryPercentRight"],
                        caseValue: dict["BatteryPercentCase"]
                    )
                }
            }
            service = IOIteratorNext(iter)
        }
        return BatteryReading(left: nil, right: nil, caseLevel: nil)
    }
}
