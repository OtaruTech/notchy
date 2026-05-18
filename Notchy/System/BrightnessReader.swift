import CoreGraphics
import Foundation

/// Reads the current display brightness via the private CoreDisplay framework.
/// `CoreDisplay_Display_GetUserBrightness` is the stable workhorse used by
/// every brightness-aware Mac utility since macOS 10.13. Linked at runtime
/// via `dlopen` so we don't take a hard private-framework dependency.
enum BrightnessReader {

    /// Returns the brightness of the built-in display in 0.0 – 1.0, or nil
    /// if CoreDisplay couldn't load / there's no main display.
    static func currentBrightness() -> Double? {
        guard let getFn = getFunction else { return nil }
        let displayID = CGMainDisplayID()
        let value = getFn(displayID)
        guard value.isFinite, value >= 0 else { return nil }
        return value
    }

    // MARK: dlopen plumbing

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID) -> Double

    private static let getFunction: GetBrightness? = {
        guard let handle = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_NOW),
              let sym = dlsym(handle, "CoreDisplay_Display_GetUserBrightness")
        else { return nil }
        return unsafeBitCast(sym, to: GetBrightness.self)
    }()
}
