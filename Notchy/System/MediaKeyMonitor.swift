import AppKit

/// Listens for system-defined media key events (brightness up/down,
/// keyboard backlight up/down) using `NSEvent.systemDefined` subtype 8
/// (NX_SUBTYPE_AUX_CONTROL_BUTTONS).
///
/// This is the only public way to detect F1/F2/F5/F6 across all keyboard
/// layouts (built-in, Magic Keyboard, third-party) without requiring
/// Accessibility access for a full key tap.
///
/// The handler is called on the MAIN actor on key-down only (releases
/// are filtered out).
@MainActor
final class MediaKeyMonitor {

    enum Key {
        case brightnessUp
        case brightnessDown
        case keyboardBacklightUp
        case keyboardBacklightDown
    }

    var onKey: (Key) -> Void = { _ in }

    private var globalMonitor: Any?
    private var localMonitor: Any?

    // NX_KEYTYPE values from <IOKit/hidsystem/ev_keymap.h>.
    private static let NX_KEYTYPE_BRIGHTNESS_UP    = 2
    private static let NX_KEYTYPE_BRIGHTNESS_DOWN  = 3
    private static let NX_KEYTYPE_ILLUMINATION_UP   = 19
    private static let NX_KEYTYPE_ILLUMINATION_DOWN = 18

    func start() {
        // Global = events targeted at OTHER apps. macOS routes media-key
        // events to the frontmost app, so we need this monitor to catch them.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
            return event
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        // subtype 8 = NX_SUBTYPE_AUX_CONTROL_BUTTONS (HID auxiliary key).
        guard event.subtype.rawValue == 8 else { return }
        let data1 = event.data1
        let keyCode = Int((data1 & 0xFFFF_0000) >> 16)
        let keyFlags = Int(data1 & 0x0000_FFFF)
        let keyState = (keyFlags & 0xFF00) >> 8  // 0x0A = down, 0x0B = up
        guard keyState == 0x0A else { return }

        switch keyCode {
        case Self.NX_KEYTYPE_BRIGHTNESS_UP:     onKey(.brightnessUp)
        case Self.NX_KEYTYPE_BRIGHTNESS_DOWN:   onKey(.brightnessDown)
        case Self.NX_KEYTYPE_ILLUMINATION_UP:   onKey(.keyboardBacklightUp)
        case Self.NX_KEYTYPE_ILLUMINATION_DOWN: onKey(.keyboardBacklightDown)
        default: break
        }
    }
}
