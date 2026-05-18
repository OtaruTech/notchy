import Foundation

/// One discrete HUD event: a volume / brightness / keyboard-backlight change
/// the system just emitted. The HUDFeature shows it in the notch panel area
/// for ~1.5s then dismisses.
struct HUDEvent: Equatable, Sendable {
    enum Kind: String, Sendable, CaseIterable {
        case volume
        case brightness
        case keyboardBacklight
    }

    let kind: Kind
    /// Normalised 0.0 – 1.0
    let level: Double
    /// Only meaningful for `.volume`. When true the bar fills using the muted
    /// styling regardless of `level`.
    let muted: Bool

    init(kind: Kind, level: Double, muted: Bool = false) {
        self.kind = kind
        self.level = max(0, min(1, level))
        self.muted = muted
    }
}

extension HUDEvent.Kind {
    var sfSymbol: String {
        switch self {
        case .volume:            return "speaker.wave.2.fill"
        case .brightness:        return "sun.max.fill"
        case .keyboardBacklight: return "keyboard.fill"
        }
    }

    var mutedSymbol: String { "speaker.slash.fill" }

    /// User-default key for the Settings toggle that gates this HUD type.
    var enabledKey: String {
        switch self {
        case .volume:            return "notchy.hudVolumeEnabled"
        case .brightness:        return "notchy.hudBrightnessEnabled"
        case .keyboardBacklight: return "notchy.hudKeyboardEnabled"
        }
    }
}
