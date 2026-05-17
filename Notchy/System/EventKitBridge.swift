import EventKit
import Foundation

actor EventKitBridge {
    private let store = EKEventStore()

    enum AccessResult: Sendable {
        case granted
        case denied
        case writeOnly
    }

    func requestAccess() async -> AccessResult {
        if #available(macOS 14, *) {
            do {
                let ok = try await store.requestFullAccessToEvents()
                return ok ? .granted : .denied
            } catch {
                return .denied
            }
        }
        return .denied
    }

    /// Today's upcoming events (now → end of day), max 5. Returns Sendable VMs.
    func todaysEvents() -> [EventVM] {
        let cal = Calendar.current
        let now = Date()
        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
        let pred = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        return store.events(matching: pred).prefix(5).map(EventVM.from(_:))
    }
}
