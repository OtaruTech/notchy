import Foundation
import Observation

/// Umbrella `@Observable` that aggregates every v0.4 system indicator.
/// Individual monitors are added in subsequent phases; the dashboard view
/// reads from this single source so adding a new indicator is a one-line
/// drop-in.
///
/// Phase 3 ships this as a scaffold with placeholder properties. Subsequent
/// phases populate them:
///   - Phase 4: chargingWatts (PowerMonitor)
///   - Phase 5: micInUse / camInUse (PrivacyMonitor)
///   - Phase 6: isCaffeinated (CaffeineController)
///   - Phase 7: networkUp / networkDown (NetworkMonitor)
///   - Phase 8: btDevices (BTBatteryMonitor)
@MainActor
@Observable
final class SystemStatusFeature {

    // Phase 4 — charging
    var chargingWatts: Int?
    var isCharging: Bool = false

    // Phase 5 — privacy indicators
    var micInUse: PrivacyConsumer?
    var camInUse: PrivacyConsumer?

    // Phase 6 — caffeine
    var isCaffeinated: Bool = false

    // Phase 7 — network
    var networkUp: Double = 0     // bytes/sec
    var networkDown: Double = 0

    // Phase 8 — BT devices
    var btDevices: [BTDeviceBattery] = []

    init() {}

    // MARK: nested data types

    struct PrivacyConsumer: Equatable, Sendable {
        var appName: String?  // Phase 5 nameless; Phase B adds attribution
    }

    struct BTDeviceBattery: Identifiable, Equatable, Sendable {
        let id: String
        let name: String
        let kind: Kind
        let main: Int?
        let left: Int?
        let right: Int?
        let caseLevel: Int?

        enum Kind: String, Sendable {
            case mouse, keyboard, watch, airpods, headphones, generic
        }
    }
}

extension SystemStatusFeature {

    /// True ⇒ at least one indicator has a user-visible value RIGHT NOW.
    /// Used by Dashboard to decide whether to show the extras section.
    var hasAnyIndicator: Bool {
        chargingWatts != nil
            || micInUse != nil
            || camInUse != nil
            || isCaffeinated
            || networkUp > 0
            || networkDown > 0
            || !btDevices.isEmpty
    }
}
