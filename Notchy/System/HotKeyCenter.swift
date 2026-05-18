import AppKit
import Carbon.HIToolbox

/// Registers global keyboard shortcuts using the Carbon HotKey API (the only
/// supported way to capture system-wide hotkeys without Accessibility prompts).
///
/// **Bindings (v0.6+):** stored in UserDefaults under
/// `notchy.hotkey.<action>` as `{ "keyCode": Int, "modifiers": UInt32 }`.
/// Carbon modifier flags (`cmdKey | optionKey | controlKey | shiftKey`).
///
/// Defaults:
///   - toggleDashboard: ⌘⌥N
///   - toggleMirror:    ⌘⌥M
///   - toggleClipboard: ⌘⇧V
///   - toggleCaffeine:  ⌘⌥K
///
/// Master switch: `notchy.hotkeysEnabled` (default true).
@MainActor
final class HotKeyCenter {

    enum Action: UInt32, CaseIterable {
        case toggleDashboard = 1
        case toggleMirror    = 2
        case toggleClipboard = 3
        case toggleCaffeine  = 4

        var defaultsKey: String { "notchy.hotkey.\(self)" }

        var displayName: String {
            switch self {
            case .toggleDashboard: return "Toggle dashboard"
            case .toggleMirror:    return "Toggle Mirror"
            case .toggleClipboard: return "Clipboard panel"
            case .toggleCaffeine:  return "Caffeine toggle"
            }
        }

        var defaultBinding: HotKeyBinding {
            switch self {
            case .toggleDashboard: return HotKeyBinding(keyCode: UInt32(kVK_ANSI_N),
                                                        modifiers: UInt32(cmdKey | optionKey))
            case .toggleMirror:    return HotKeyBinding(keyCode: UInt32(kVK_ANSI_M),
                                                        modifiers: UInt32(cmdKey | optionKey))
            case .toggleClipboard: return HotKeyBinding(keyCode: UInt32(kVK_ANSI_V),
                                                        modifiers: UInt32(cmdKey | shiftKey))
            case .toggleCaffeine:  return HotKeyBinding(keyCode: UInt32(kVK_ANSI_K),
                                                        modifiers: UInt32(cmdKey | optionKey))
            }
        }
    }

    /// Fired on the main actor when a registered hotkey fires.
    var onAction: (Action) -> Void = { _ in }

    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var started = false

    private static var sharedInstance: HotKeyCenter?

    func start() {
        guard UserDefaults.standard.object(forKey: "notchy.hotkeysEnabled") as? Bool ?? true else {
            return
        }
        HotKeyCenter.sharedInstance = self
        installHandler()
        registerAll()
        started = true
    }

    func stop() {
        unregisterAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
        started = false
    }

    /// Re-read bindings from UserDefaults and re-register.
    /// Called by Settings when the user records a new shortcut.
    func reloadBindings() {
        guard started else { return }
        unregisterAll()
        registerAll()
    }

    // MARK: bindings

    static func binding(for action: Action) -> HotKeyBinding {
        if let dict = UserDefaults.standard.dictionary(forKey: action.defaultsKey),
           let keyCode = (dict["keyCode"] as? NSNumber)?.uint32Value,
           let modifiers = (dict["modifiers"] as? NSNumber)?.uint32Value {
            return HotKeyBinding(keyCode: keyCode, modifiers: modifiers)
        }
        return action.defaultBinding
    }

    static func setBinding(_ binding: HotKeyBinding?, for action: Action) {
        if let binding {
            UserDefaults.standard.set([
                "keyCode": NSNumber(value: binding.keyCode),
                "modifiers": NSNumber(value: binding.modifiers)
            ], forKey: action.defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: action.defaultsKey)
        }
    }

    static func resetAllToDefaults() {
        for action in Action.allCases {
            UserDefaults.standard.removeObject(forKey: action.defaultsKey)
        }
    }

    // MARK: private

    private func registerAll() {
        for action in Action.allCases {
            let b = Self.binding(for: action)
            register(keyCode: b.keyCode, modifiers: b.modifiers, id: action)
        }
    }

    private func unregisterAll() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
    }

    private func register(keyCode: UInt32, modifiers: UInt32, id: Action) {
        let hkID = EventHotKeyID(signature: OSType(0x4E54_4359 /* 'NTCY' */), id: id.rawValue)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hkID, GetEventDispatcherTarget(), 0, &ref)
        if status == noErr, let ref { refs.append(ref) }
    }

    private func installHandler() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, eventRef, _ -> OSStatus in
            guard let eventRef else { return OSStatus(eventNotHandledErr) }
            var hk = EventHotKeyID()
            let s = GetEventParameter(eventRef, EventParamName(kEventParamDirectObject),
                                       EventParamType(typeEventHotKeyID), nil,
                                       MemoryLayout<EventHotKeyID>.size, nil, &hk)
            guard s == noErr, let action = Action(rawValue: hk.id) else {
                return OSStatus(eventNotHandledErr)
            }
            DispatchQueue.main.async {
                HotKeyCenter.sharedInstance?.onAction(action)
            }
            return noErr
        }, 1, &spec, nil, &handler)
    }
}

/// Plain value type representing a single Carbon hotkey binding.
struct HotKeyBinding: Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32      // Carbon flags (cmdKey | optionKey | shiftKey | controlKey)

    /// Human-readable label e.g. `⌘⌥N`.
    var displayString: String {
        var out = ""
        if (modifiers & UInt32(controlKey)) != 0 { out += "⌃" }
        if (modifiers & UInt32(optionKey))  != 0 { out += "⌥" }
        if (modifiers & UInt32(shiftKey))   != 0 { out += "⇧" }
        if (modifiers & UInt32(cmdKey))     != 0 { out += "⌘" }
        out += HotKeyKeyMap.label(for: keyCode)
        return out
    }
}

/// Maps Carbon `kVK_*` virtual key codes to single-character labels for the
/// hotkey field. Only the most common keys are listed; unknown codes fall back
/// to `"#42"` so the user can still tell something registered.
enum HotKeyKeyMap {
    static func label(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Comma:   return ","
        case kVK_ANSI_Period:  return "."
        case kVK_ANSI_Slash:   return "/"
        case kVK_Space:        return "␣"
        case kVK_Return:       return "↩"
        case kVK_Tab:          return "⇥"
        case kVK_Escape:       return "⎋"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return "#\(keyCode)"
        }
    }
}
