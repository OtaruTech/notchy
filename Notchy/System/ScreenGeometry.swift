import AppKit
import Foundation

enum ScreenGeometry {
    /// Fallback notch width in points when the system APIs don't expose
    /// `auxiliaryTopLeftArea/RightArea` (older macOS or non-notched screens).
    /// 210 is the typical width on M1/M2/M3 14" MacBook Pro; M3 16" is ~225.
    static let notchWidth: CGFloat = 210

    /// Buffer below the notch that still triggers expansion.
    static let hotZoneBuffer: CGFloat = 4

    /// True hardware notch width derived from `NSScreen.auxiliaryTopLeftArea` /
    /// `auxiliaryTopRightArea` (macOS 12+). Returns the fallback constant if not
    /// available. Use this for visual alignment (live activity strip, panel sizing).
    @MainActor
    static func liveNotchWidth() -> CGFloat {
        guard let screen = notchedScreen() else { return notchWidth }
        let leftMaxX = screen.auxiliaryTopLeftArea?.maxX ?? 0
        let rightMinX = screen.auxiliaryTopRightArea?.minX ?? 0
        let width = rightMinX - leftMaxX
        return width > 0 ? width : notchWidth
    }

    /// True hardware notch height — usually 32pt, but some Macs report 38pt.
    @MainActor
    static func liveNotchHeight() -> CGFloat {
        guard let screen = notchedScreen() else { return 32 }
        return screen.safeAreaInsets.top
    }

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
