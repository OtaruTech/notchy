import AppKit
import Carbon.HIToolbox

/// Registers global keyboard shortcuts using the Carbon HotKey API (the only
/// supported way to capture system-wide hotkeys without Accessibility prompts).
///
/// Shortcuts:
///   - ⌘⌥N  toggle dashboard / collapse
///   - ⌘⌥M  toggle Mirror
///
/// Both can be disabled via the `notchy.hotkeysEnabled` UserDefault (default true).
@MainActor
final class HotKeyCenter {

    enum Action: UInt32 {
        case toggleDashboard = 1
        case toggleMirror    = 2
        case toggleClipboard = 3
        case toggleCaffeine  = 4
    }

    /// Fired on the main actor when a registered hotkey fires.
    var onAction: (Action) -> Void = { _ in }

    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    private static var sharedInstance: HotKeyCenter?

    func start() {
        guard UserDefaults.standard.object(forKey: "notchy.hotkeysEnabled") as? Bool ?? true else {
            return
        }
        HotKeyCenter.sharedInstance = self
        installHandler()
        register(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(cmdKey | optionKey), id: .toggleDashboard)
        register(keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey | optionKey), id: .toggleMirror)
        register(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey), id: .toggleClipboard)
        register(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | optionKey), id: .toggleCaffeine)
    }

    func stop() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    private func register(keyCode: UInt32, modifiers: UInt32, id: Action) {
        let hkID = EventHotKeyID(signature: OSType(0x4E54_4359 /* 'NTCY' */), id: id.rawValue)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hkID, GetEventDispatcherTarget(), 0, &ref)
        if status == noErr, let ref { refs.append(ref) }
    }

    private func installHandler() {
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
