import AppKit
import Foundation

enum ScreenGeometry {
    /// Width of the hardware notch in points across all notched MacBooks.
    static let notchWidth: CGFloat = 210

    /// Buffer below the notch that still triggers expansion.
    static let hotZoneBuffer: CGFloat = 4

    /// Returns the notch rectangle in screen-local coordinates (origin at top-left).
    /// `safeAreaTop` is `NSScreen.safeAreaInsets.top`.
    static func notchRect(safeAreaTop: CGFloat, screenFrame: CGRect) -> CGRect? {
        guard safeAreaTop > 0 else { return nil }
        let x = screenFrame.midX - notchWidth / 2
        return CGRect(x: x, y: 0, width: notchWidth, height: safeAreaTop)
    }

    /// Hot zone is the notch rect extended `hotZoneBuffer` points downward.
    static func hotZone(safeAreaTop: CGFloat, screenFrame: CGRect) -> CGRect? {
        guard let notch = notchRect(safeAreaTop: safeAreaTop, screenFrame: screenFrame) else { return nil }
        return CGRect(x: notch.minX, y: notch.minY, width: notch.width, height: notch.height + hotZoneBuffer)
    }

    /// Convenience: returns the first screen with a notch, or `nil`.
    @MainActor
    static func notchedScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
    }
}
