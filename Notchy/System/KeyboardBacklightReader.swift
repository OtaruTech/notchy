import Foundation
import IOKit

/// Reads keyboard backlight level via `AppleHIDKeyboardEventDriverV2` IOService.
/// The returned value is a 0…1 fraction.
///
/// Macs without an illuminated keyboard (or with the level unavailable to
/// non-Apple processes) return nil — the HUD then falls back to a
/// directional pulse.
enum KeyboardBacklightReader {

    static func currentLevel() -> Double? {
        // Property "KeyboardBacklight" or "BacklightLevel" depending on the
        // model. We probe a few candidates.
        let serviceNames = [
            "AppleHIDKeyboardEventDriverV2",
            "AppleHIDKeyboardEventDriver",
            "AppleKeyboardBacklight",
        ]
        let propertyKeys = ["KeyboardBacklight", "Brightness", "BacklightLevel"]

        for name in serviceNames {
            let matching = IOServiceMatching(name)
            let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
            guard service != 0 else { continue }
            defer { IOObjectRelease(service) }

            for key in propertyKeys {
                let prop = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)
                if let v = prop?.takeRetainedValue() as? NSNumber {
                    // Apple reports as 0…65535 sometimes, 0…1 other times.
                    let raw = v.doubleValue
                    if raw <= 1.0 { return raw }
                    return raw / 65535.0
                }
            }
        }
        return nil
    }
}
